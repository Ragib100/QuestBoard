from datetime import date, datetime, timezone
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import (
    ChallengeAttempt,
    DailyChallenge,
    PointReason,
    User,
)
from app.services import codeforces_service as cf
from app.services.activity_service import ActivityService
from app.services.badge_service import BadgeService
from app.services.point_service import PointService


class ChallengeService:
    """The daily Codeforces challenge.

    There is no cron job. Today's row is created lazily by whoever asks first
    ([decisions.md](../../docs/decisions.md) D17 applies the same reasoning to
    the weekly leaderboard) — a scheduled worker would be one more thing to
    deploy and one more thing to notice had died.
    """

    @staticmethod
    def _today() -> date:
        return datetime.now(timezone.utc).date()

    @classmethod
    def today(cls, db: Session) -> DailyChallenge:
        """Today's challenge, creating it from Codeforces if needed.

        Raises LookupError when Codeforces is unreachable *and* we have never
        stored a challenge — there is nothing honest to show in that case.
        """
        today = cls._today()

        existing = db.scalar(
            select(DailyChallenge).where(DailyChallenge.challenge_date == today)
        )
        if existing is not None:
            return existing

        try:
            problem = cf.pick_problem(today.isoformat())
        except cf.CodeforcesError:
            # Fall back to the most recent challenge we did manage to store, so
            # the screen shows a real problem with an honest "not today's"
            # label rather than an error or an invented one.
            latest = db.scalar(
                select(DailyChallenge).order_by(DailyChallenge.challenge_date.desc())
            )
            if latest is None:
                raise LookupError(
                    "Codeforces is unreachable and no challenge has been "
                    "stored yet. Try again shortly."
                )
            return latest

        codeforces_id = f"{problem['contestId']}/{problem['index']}"
        rating = problem.get("rating")
        tags = ", ".join(problem.get("tags") or []) or "no tags"

        challenge = DailyChallenge(
            codeforces_id=codeforces_id,
            title=problem["name"],
            # Codeforces does not expose statements through the API, so the
            # body says what we actually know and points at the real one.
            body=(
                f"Codeforces problem {codeforces_id} — rated {rating or 'unrated'}.\n"
                f"Topics: {tags}.\n\n"
                "Read the full statement and submit your solution on Codeforces, "
                "then come back and claim your bonus."
            ),
            cf_rating=rating,
            difficulty=cf.difficulty_for(rating),
            source_url=cf.problem_url(codeforces_id),
            challenge_date=today,
        )
        db.add(challenge)

        try:
            db.commit()
        except IntegrityError:
            # Another request created today's row between our SELECT and this
            # INSERT. `challenge_date` is unique, which is what made that safe.
            db.rollback()
            return db.scalar(
                select(DailyChallenge).where(DailyChallenge.challenge_date == today)
            )

        db.refresh(challenge)
        return challenge

    @staticmethod
    def attempt_of(
        db: Session, challenge_id: UUID, user_id: UUID
    ) -> ChallengeAttempt | None:
        return db.scalar(
            select(ChallengeAttempt).where(
                ChallengeAttempt.challenge_id == challenge_id,
                ChallengeAttempt.user_id == user_id,
            )
        )

    @staticmethod
    def solved_count(db: Session, user_id: UUID) -> int:
        return int(
            db.scalar(
                select(func.count(ChallengeAttempt.id)).where(
                    ChallengeAttempt.user_id == user_id,
                    ChallengeAttempt.is_solved.is_(True),
                )
            )
            or 0
        )

    @classmethod
    def claim(cls, db: Session, challenge_id: UUID, user_id: UUID) -> ChallengeAttempt:
        """Verifies the solve against Codeforces, then pays the bonus.

        Raises LookupError (unknown challenge or profile), PermissionError
        (no verified handle), ValueError (Codeforces says it is not solved) or
        RuntimeError (Codeforces unreachable).
        """
        challenge = db.get(DailyChallenge, challenge_id)
        if challenge is None:
            raise LookupError("That challenge does not exist.")

        user = db.get(User, user_id)
        if user is None:
            raise LookupError("Finish setting up your profile first.")

        if not user.codeforces_verified or not user.codeforces_handle:
            raise PermissionError(
                "Verify your Codeforces handle on your profile before claiming "
                "a challenge."
            )

        existing = cls.attempt_of(db, challenge_id, user_id)
        if existing is not None and existing.is_solved:
            raise ValueError("You have already claimed this challenge.")

        if challenge.codeforces_id is None:
            raise ValueError("This challenge has no Codeforces problem to check.")

        try:
            solved = cf.has_solved(user.codeforces_handle, challenge.codeforces_id)
        except cf.CodeforcesError as e:
            raise RuntimeError(str(e))

        if not solved:
            # Record the attempt anyway: the user tried, and the row is what
            # lets the screen say "not accepted yet" instead of nothing.
            if existing is None:
                existing = ChallengeAttempt(
                    challenge_id=challenge_id, user_id=user_id, is_solved=False
                )
                db.add(existing)
                db.commit()
            raise ValueError(
                "Codeforces has no accepted submission from "
                f"{user.codeforces_handle} for this problem yet."
            )

        attempt = existing or ChallengeAttempt(
            challenge_id=challenge_id, user_id=user_id
        )
        attempt.is_solved = True
        attempt.solved_at = datetime.now(timezone.utc).replace(tzinfo=None)
        db.add(attempt)

        ActivityService.record(db, user)
        PointService.apply(
            db,
            user,
            challenge.bonus_points,
            PointReason.CHALLENGE_SOLVED,
            reference_id=challenge.id,
        )
        BadgeService.sync(db, user)

        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            raise ValueError("You have already claimed this challenge.")

        db.refresh(attempt)
        return attempt

    @staticmethod
    def leaderboard(db: Session, challenge_id: UUID, limit: int = 50) -> list[dict]:
        """Solvers, fastest first. Public — no token needed."""
        rows = db.execute(
            select(ChallengeAttempt, User)
            .join(User, User.id == ChallengeAttempt.user_id)
            .where(
                ChallengeAttempt.challenge_id == challenge_id,
                ChallengeAttempt.is_solved.is_(True),
            )
            .order_by(ChallengeAttempt.solved_at.asc())
            .limit(limit)
        ).all()

        return [
            {"rank": i, "solved_at": attempt.solved_at, "user": user}
            for i, (attempt, user) in enumerate(rows, start=1)
        ]
