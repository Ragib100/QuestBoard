from sqlalchemy import Boolean, Column, DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID

from app.db.base import Base


class NotificationType:
    """The only values `notifications.type` accepts.

    Enforced by a CHECK constraint in the database, so adding a member here
    without a migration will fail at insert time.
    """

    ANSWER_RECEIVED = "answer_received"
    ANSWER_ACCEPTED = "answer_accepted"
    BOUNTY_AWARDED = "bounty_awarded"
    VOTE_RECEIVED = "vote_received"
    BADGE_EARNED = "badge_earned"


class Notification(Base):
    __tablename__ = "notifications"

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
    type = Column(String(30), nullable=False)
    message = Column(Text, nullable=False)
    # The quest, answer or badge the notification points at. Polymorphic, so no
    # foreign key — the type tells you which table to look in.
    reference_id = Column(UUID(as_uuid=True))
    is_read = Column(Boolean, nullable=False, server_default="false")
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
