from sqlalchemy import Column, DateTime, ForeignKey, Integer, Text, func
from sqlalchemy.dialects.postgresql import UUID

from app.db.base import Base

HINT_COST = 5


class AiHint(Base):
    """One row per hint the model actually returned.

    Doubles as the rate-limit ledger — the hourly cap is a COUNT over
    `created_at` — and as the evidence for the `ai_skeptic` badge, which is
    awarded for solving a quest you never asked for a hint on. A failed model
    call must therefore leave no row behind.
    """

    __tablename__ = "ai_hints"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    question_id = Column(
        UUID(as_uuid=True),
        ForeignKey("questions.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    hint_text = Column(Text, nullable=False)
    points_cost = Column(Integer, nullable=False, server_default=str(HINT_COST))
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
