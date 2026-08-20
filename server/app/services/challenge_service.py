from datetime import date
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core import clock
from app.models import (
    ChallengeAttempt,
    DailyChallenge,
    PointReason,
    User,
    award_for,
)
from app.schemas.code import CodeSubmission, apply_submission
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
        """Bangladesh's today — the challenge rolls over at midnight Dhaka."""
        return clock.today()

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

    @classmethod
    def get(cls, db: Session, challenge_id: UUID) -> DailyChallenge:
        challenge = db.get(DailyChallenge, challenge_id)
        if challenge is None:
            raise LookupError("That challenge does not exist.")
        return challenge

    @classmethod
    def award_now(cls, challenge: DailyChallenge) -> int:
        """What solving `challenge` is worth today, after the age decay."""
        return award_for(challenge.bonus_points, challenge.challenge_date)

    @classmethod
    def archive_page(
        cls,
        db: Session,
        *,
        page: int = 1,
        limit: int = 20,
        include_today: bool = False,
        viewer_id: UUID | None = None,
    ) -> tuple[list[dict], int]:
        """Past challenges, newest first, with the viewer's own attempt.

        The solver counts and the viewer's attempts are fetched in two grouped
        queries rather than one per row — the archive grows by a row a day and
        an N+1 here would get slower every morning.
        """
        today = cls._today()

        where = () if include_today else (DailyChallenge.challenge_date < today,)

        total = int(db.scalar(select(func.count(DailyChallenge.id)).where(*where)) or 0)

        challenges = list(
            db.scalars(
                select(DailyChallenge)
                .where(*where)
                .order_by(DailyChallenge.challenge_date.desc())
                .offset((page - 1) * limit)
                .limit(limit)
            )
        )
        if not challenges:
            return [], total

        ids = [c.id for c in challenges]

        counts = dict(
            db.execute(
                select(
                    ChallengeAttempt.challenge_id,
                    func.count(ChallengeAttempt.id),
                )
                .where(
                    ChallengeAttempt.challenge_id.in_(ids),
                    ChallengeAttempt.is_solved.is_(True),
                )
                .group_by(ChallengeAttempt.challenge_id)
            ).all()
        )

        attempts: dict[UUID, ChallengeAttempt] = {}
        if viewer_id is not None:
            attempts = {
                a.challenge_id: a
                for a in db.scalars(
                    select(ChallengeAttempt).where(
                        ChallengeAttempt.challenge_id.in_(ids),
                        ChallengeAttempt.user_id == viewer_id,
                    )
                )
            }

        rows = [
            {
                "challenge": c,
                "solver_count": int(counts.get(c.id, 0)),
                "attempt": attempts.get(c.id),
            }
            for c in challenges
        ]
        return rows, total

    @staticmethod
    def attempt_of(
        db: Session,
        challenge_id: UUID,
        user_id: UUID,
        for_update: bool = False,
    ) -> ChallengeAttempt | None:
        """This user's attempt at this challenge, if they have one.

        `for_update` locks the row for the rest of the transaction. Claiming
        needs it: the unique constraint stops two concurrent *first* claims,
        but once an unsolved attempt exists both racers would UPDATE it and
        both would be paid.
        """
        query = select(ChallengeAttempt).where(
            ChallengeAttempt.challenge_id == challenge_id,
            ChallengeAttempt.user_id == user_id,
        )
        if for_update:
            query = query.with_for_update()
        return db.scalar(query)

    @staticmethod
    def _count_solved(db: Session, *filters) -> int:
        return int(
            db.scalar(
                select(func.count(ChallengeAttempt.id)).where(
                    ChallengeAttempt.is_solved.is_(True), *filters
                )
            )
            or 0
        )

    @classmethod
    def solved_by(cls, db: Session, user_id: UUID) -> int:
        """How many challenges this user has solved — the `challenger` badge."""
        return cls._count_solved(db, ChallengeAttempt.user_id == user_id)

    @classmethod
    def solver_count(cls, db: Session, challenge_id: UUID) -> int:
        """How many people solved this challenge — shown on the screen."""
        return cls._count_solved(db, ChallengeAttempt.challenge_id == challenge_id)

    @staticmethod
    def _not_solved_message(handle, since, stale_at) -> str:
        """Why the claim was refused, in the terms the user is thinking in.

        "No accepted submission" and "your accepted submission is from before
        this challenge existed" are different problems with different fixes,
        and telling someone who just solved it that we cannot see any
        submission at all sends them looking in the wrong place.
        """
        day = since.strftime("%-d %b")

        if stale_at is not None and stale_at < since:
            return (
                f"Your last submission for this problem is from "
                f"{stale_at.astimezone(clock.DHAKA).strftime('%-d %b %Y')}, before "
                f"this challenge opened on {day}. Submit it again on Codeforces "
                "to claim — old solves do not count."
            )

        return (
            f"Codeforces has no accepted submission from {handle} for this "
            f"problem since {day}. Submit your solution there first, then "
            "claim — a verdict can take a minute to land."
        )

    @classmethod
    def claim(
        cls,
        db: Session,
        challenge_id: UUID,
        user_id: UUID,
        data: CodeSubmission | None = None,
    ) -> ChallengeAttempt:
        """Verifies the solve against Codeforces, then pays the decayed award.

        The amount is `award_for(bonus_points, challenge_date)` — the challenge's
        full value on its own day, less 10% of it per day since, floored at 20%.
        A challenge from last month is still worth solving; it is not worth what
        today's is.

        The accepted submission has to be dated on or after the challenge's own
        day (midnight Dhaka). Solving it last year does not pay.

        `data` carries the solution the user typed or uploaded in the app. It is
        stored on the attempt either way: the bonus is paid on the Codeforces
        verdict, so submitting code proves nothing, but losing what someone
        typed because their verdict had not landed yet would be its own bug.

        Raises LookupError (unknown challenge or profile), PermissionError
        (no verified handle), ValueError (Codeforces says it is not solved) or
        RuntimeError (Codeforces unreachable).
        """
        challenge = cls.get(db, challenge_id)

        user = db.get(User, user_id)
        if user is None:
            raise LookupError("Finish setting up your profile first.")

        if not user.codeforces_verified or not user.codeforces_handle:
            raise PermissionError(
                "Verify your Codeforces handle on your profile before claiming "
                "a challenge."
            )

        existing = cls.attempt_of(db, challenge_id, user_id, for_update=True)
        if existing is not None and existing.is_solved:
            raise ValueError("You have already claimed this challenge.")

        if challenge.codeforces_id is None:
            raise ValueError("This challenge has no Codeforces problem to check.")

        # The solve has to have been made *for* this challenge. Codeforces
        # keeps a submission history forever, so without a lower bound anyone
        # who solved the problem years ago could claim without opening it.
        since = clock.start_of_day(challenge.challenge_date)

        try:
            solved = cf.has_solved(
                user.codeforces_handle, challenge.codeforces_id, since
            )
            stale_at = (
                None
                if solved
                else cf.last_attempt_at(user.codeforces_handle, challenge.codeforces_id)
            )
        except cf.CodeforcesError as e:
            raise RuntimeError(str(e))

        if not solved:
            # Record the attempt anyway: the user tried, and the row is what
            # lets the screen say "not accepted yet" instead of nothing. Their
            # code is kept too, so a premature claim does not lose their work.
            if existing is None:
                existing = ChallengeAttempt(
                    challenge_id=challenge_id, user_id=user_id, is_solved=False
                )
                db.add(existing)
            if data is not None:
                apply_submission(existing, data)
            db.commit()
            raise ValueError(
                cls._not_solved_message(user.codeforces_handle, since, stale_at)
            )

        attempt = existing or ChallengeAttempt(
            challenge_id=challenge_id, user_id=user_id
        )
        attempt.is_solved = True
        attempt.solved_at = clock.naive_utc_now()
        if data is not None:
            apply_submission(attempt, data)

        # Priced at claim time, then stored: `bonus_points` alone cannot say
        # what a late solve paid, and the leaderboard has to agree with the
        # ledger about that forever after.
        award = cls.award_now(challenge)
        attempt.awarded_points = award
        db.add(attempt)

        ActivityService.record(db, user)
        PointService.apply(
            db,
            user,
            award,
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
            {
                "rank": i,
                "solved_at": attempt.solved_at,
                "awarded_points": attempt.awarded_points or 0,
                "user": user,
            }
            for i, (attempt, user) in enumerate(rows, start=1)
        ]
