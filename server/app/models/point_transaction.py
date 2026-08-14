from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID

from app.db.base import Base


class PointReason:
    """Every value `point_transactions.reason` may take.

    Kept in one place so the ledger stays queryable — see docs/product.md.
    """

    SIGNUP_BONUS = "signup_bonus"
    BOUNTY_POSTED = "bounty_posted"
    BOUNTY_REFUNDED = "bounty_refunded"
    BOUNTY_AWARDED = "bounty_awarded"
    VOTE_RECEIVED = "vote_received"
    VOTE_LOST = "vote_lost"
    DAILY_BONUS = "daily_bonus"
    CHALLENGE_SOLVED = "challenge_solved"
    AI_HINT = "ai_hint"


class PointTransaction(Base):
    """Append-only ledger. Never UPDATE or DELETE a row: `users.points` is a
    cache of this table's sum and the two must move together."""

    __tablename__ = "point_transactions"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    amount = Column(Integer, nullable=False)
    reason = Column(String(50), nullable=False)
    reference_id = Column(UUID(as_uuid=True))
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
