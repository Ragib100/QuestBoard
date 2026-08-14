from sqlalchemy import Column, DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.base import Base


class BadgeCode:
    """Badge names as seeded in the `badges` table.

    `CHALLENGER` and `AI_SKEPTIC` depend on the daily challenge and AI hints,
    which do not exist yet — they are listed so the catalogue is complete, but
    nothing awards them until M4.
    """

    FIRST_ANSWER = "first_answer"
    FIRST_BOUNTY = "first_bounty"
    BOUNTY_HUNTER = "bounty_hunter"
    STREAK_5 = "streak_5"
    STREAK_30 = "streak_30"
    TOP_HELPER = "top_helper"
    CHALLENGER = "challenger"
    AI_SKEPTIC = "ai_skeptic"


class Badge(Base):
    __tablename__ = "badges"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    name = Column(String(50), nullable=False, unique=True)
    description = Column(Text, nullable=False)
    icon_url = Column(Text)


class UserBadge(Base):
    """Join row. The composite primary key is what makes awarding idempotent —
    a second award of the same badge simply conflicts and is ignored."""

    __tablename__ = "user_badges"

    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    badge_id = Column(
        UUID(as_uuid=True),
        ForeignKey("badges.id", ondelete="CASCADE"),
        primary_key=True,
    )
    awarded_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    badge = relationship("Badge", lazy="joined")
