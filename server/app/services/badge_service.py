from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import (
    AiHint,
    Answer,
    Badge,
    BadgeCode,
    NotificationType,
    PointReason,
    PointTransaction,
    User,
    UserBadge,
)
from app.services.notification_service import NotificationService


class BadgeService:
    """Awards achievement badges.

    Checks run inline, in the same transaction as the event that triggered them,
    rather than as a background task. They are three cheap COUNT queries, and
    running them inline means a badge can never be silently lost when a
    background worker dies — the alternative traded correctness for a few
    milliseconds we do not need.

    Awarding is idempotent: `user_badges` has a composite primary key, so a
    repeat award conflicts and is skipped.
    """

    @staticmethod
    def _earned_codes(db: Session, user_id: UUID) -> set[str]:
        return set(
            db.scalars(
                select(Badge.name)
                .join(UserBadge, UserBadge.badge_id == Badge.id)
                .where(UserBadge.user_id == user_id)
            ).all()
        )

    @staticmethod
    def _bounties_won(db: Session, user_id: UUID) -> int:
        return int(
            db.scalar(
                select(func.count(PointTransaction.id)).where(
                    PointTransaction.user_id == user_id,
                    PointTransaction.reason == PointReason.BOUNTY_AWARDED,
                )
            )
            or 0
        )

    @staticmethod
    def _answers_posted(db: Session, user_id: UUID) -> int:
        return int(
            db.scalar(select(func.count(Answer.id)).where(Answer.author_id == user_id))
            or 0
        )

    @staticmethod
    def _unaided_solves(db: Session, user_id: UUID) -> int:
        """Accepted answers on quests the user never bought a hint for.

        This is what `ai_skeptic` means — "solved a question without using any
        AI hints" — so the check is per quest, not per account: buying a hint
        once does not disqualify every later answer.
        """
        hinted = select(AiHint.question_id).where(AiHint.user_id == user_id)
        return int(
            db.scalar(
                select(func.count(Answer.id)).where(
                    Answer.author_id == user_id,
                    Answer.is_accepted.is_(True),
                    Answer.question_id.notin_(hinted),
                )
            )
            or 0
        )

    @classmethod
    def _qualifying_codes(cls, db: Session, user: User) -> set[str]:
        """Which badges the user's current stats justify."""
        earned = set()

        if cls._answers_posted(db, user.id) >= 1:
            earned.add(BadgeCode.FIRST_ANSWER)

        bounties = cls._bounties_won(db, user.id)
        if bounties >= 1:
            earned.add(BadgeCode.FIRST_BOUNTY)
        if bounties >= 10:
            earned.add(BadgeCode.BOUNTY_HUNTER)

        if user.streak_days >= 5:
            earned.add(BadgeCode.STREAK_5)
        if user.streak_days >= 30:
            earned.add(BadgeCode.STREAK_30)

        # Imported here, not at module scope: ChallengeService awards badges
        # after a solve, so it imports this module — taking the dependency at
        # import time would close the cycle.
        from app.services.challenge_service import ChallengeService

        if ChallengeService.solved_by(db, user.id) >= 7:
            earned.add(BadgeCode.CHALLENGER)

        if cls._unaided_solves(db, user.id) >= 1:
            earned.add(BadgeCode.AI_SKEPTIC)

        # TOP_HELPER still needs a weekly-rank check on a schedule.
        return earned

    @classmethod
    def award(cls, db: Session, user: User, code: str) -> Badge | None:
        """Grants one badge if the user does not already have it."""
        badge = db.scalar(select(Badge).where(Badge.name == code))
        if badge is None:
            return None

        already = db.get(UserBadge, {"user_id": user.id, "badge_id": badge.id})
        if already is not None:
            return None

        db.add(UserBadge(user_id=user.id, badge_id=badge.id))
        # The session runs with autoflush off, so without this the row stays
        # invisible to the very next query and the badge is awarded twice.
        db.flush()
        NotificationService.create(
            db,
            user_id=user.id,
            notification_type=NotificationType.BADGE_EARNED,
            message=f'You earned the "{badge.name}" badge — {badge.description}.',
            reference_id=badge.id,
        )
        return badge

    @classmethod
    def sync(cls, db: Session, user: User) -> list[Badge]:
        """Awards every badge the user now qualifies for. Does not commit."""
        qualifying = cls._qualifying_codes(db, user)
        missing = qualifying - cls._earned_codes(db, user.id)

        awarded = []
        for code in sorted(missing):
            badge = cls.award(db, user, code)
            if badge is not None:
                awarded.append(badge)

        return awarded

    @staticmethod
    def for_user(db: Session, user_id: UUID) -> list[UserBadge]:
        return list(
            db.scalars(
                select(UserBadge)
                .where(UserBadge.user_id == user_id)
                .order_by(UserBadge.awarded_at.desc())
            ).all()
        )

    @staticmethod
    def catalogue(db: Session) -> list[Badge]:
        return list(db.scalars(select(Badge).order_by(Badge.name)).all())
