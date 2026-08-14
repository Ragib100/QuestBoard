from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    SmallInteger,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID

from app.db.base import Base

TARGET_QUESTION = "question"
TARGET_ANSWER = "answer"


class Vote(Base):
    """One row per user per target. The unique constraint is what makes the
    toggle safe: re-voting the same value deletes the row, the opposite flips
    it, and a race can only ever collide on the constraint."""

    __tablename__ = "votes"
    __table_args__ = (
        UniqueConstraint("user_id", "target_type", "target_id"),
        CheckConstraint("value in (1, -1)"),
    )

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
    # Polymorphic by design — no FK, since the target may be either table.
    target_type = Column(String(10), nullable=False)
    target_id = Column(UUID(as_uuid=True), nullable=False)
    value = Column(SmallInteger, nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
