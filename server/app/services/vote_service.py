from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import (
    TARGET_ANSWER,
    TARGET_QUESTION,
    Answer,
    PointReason,
    Question,
    User,
    Vote,
)
from app.services.activity_service import ActivityService
from app.services.point_service import PointService
from app.services.user_service import UserService


class VoteService:
    """Voting moves a point to or from the content's author.

    Toggle rules: casting the same value again clears the vote, the opposite
    value flips it. The author's balance is adjusted by the *delta* between the
    old and new vote, never recomputed, so the ledger stays a true history.
    """

    @staticmethod
    def count_for(db: Session, target_type: str, target_id: UUID) -> int:
        total = db.scalar(
            select(func.coalesce(func.sum(Vote.value), 0)).where(
                Vote.target_type == target_type,
                Vote.target_id == target_id,
            )
        )
        return int(total or 0)

    @staticmethod
    def my_vote(db: Session, user_id: UUID, target_type: str, target_id: UUID) -> int:
        existing = db.scalar(
            select(Vote.value).where(
                Vote.user_id == user_id,
                Vote.target_type == target_type,
                Vote.target_id == target_id,
            )
        )
        return int(existing or 0)

    @staticmethod
    def _load_target(db: Session, target_type: str, target_id: UUID):
        model = Question if target_type == TARGET_QUESTION else Answer
        target = db.get(model, target_id)
        if target is None:
            raise LookupError(f"That {target_type} does not exist.")
        return target

    @classmethod
    def cast(
        cls,
        db: Session,
        user_id: UUID,
        target_type: str,
        target_id: UUID,
        value: int,
    ) -> tuple[int, int]:
        """Returns the target's new (vote_count, my_vote)."""
        if target_type not in (TARGET_QUESTION, TARGET_ANSWER):
            raise ValueError("Unknown vote target.")

        # Before anything is written: a suspended account may read, but the
        # ±1 a vote moves is real points changing hands.
        voter = UserService.require_active(db, user_id)

        target = cls._load_target(db, target_type, target_id)

        if target.author_id == user_id:
            raise PermissionError("You cannot vote on your own post.")

        existing = db.scalar(
            select(Vote).where(
                Vote.user_id == user_id,
                Vote.target_type == target_type,
                Vote.target_id == target_id,
            )
        )

        previous = existing.value if existing else 0

        if existing is None:
            db.add(
                Vote(
                    user_id=user_id,
                    target_type=target_type,
                    target_id=target_id,
                    value=value,
                )
            )
            new_value = value
        elif existing.value == value:
            db.delete(existing)
            new_value = 0
        else:
            existing.value = value
            new_value = value

        ActivityService.record(db, voter)

        delta = new_value - previous
        if delta:
            author = db.get(User, target.author_id)
            if author is not None:
                PointService.apply(
                    db,
                    author,
                    delta,
                    PointReason.VOTE_RECEIVED if delta > 0 else PointReason.VOTE_LOST,
                    reference_id=target_id,
                    # The author's balance, not the voter's, and the voter is
                    # the one whose request would fail. An author who has spent
                    # everything can still be downvoted — see PointService.apply.
                    allow_negative=True,
                )

        db.flush()
        return cls.count_for(db, target_type, target_id), new_value
