from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID

from app.db.base import Base

CHALLENGE_BONUS = 50


class Difficulty:
    """The only values `daily_challenges.difficulty` accepts — a CHECK
    constraint in the database enforces the same three."""

    EASY = "easy"
    MEDIUM = "medium"
    HARD = "hard"


class DailyChallenge(Base):
    """One Codeforces problem per calendar day (UTC).

    `challenge_date` is unique, which is what makes "today's challenge" a
    lookup rather than a decision: the first request of the day creates the
    row, everyone after reads it.
    """

    __tablename__ = "daily_challenges"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    # "1873/D" — contest id and problem index, the pair Codeforces keys on.
    codeforces_id = Column(Text)
    title = Column(Text, nullable=False)
    body = Column(Text, nullable=False)
    cf_rating = Column(Integer)
    difficulty = Column(String(10))
    source_url = Column(Text)
    bonus_points = Column(Integer, nullable=False, server_default=str(CHALLENGE_BONUS))
    challenge_date = Column(Date, nullable=False, unique=True)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class ChallengeAttempt(Base):
    """A user's participation in one daily challenge.

    Unique on (challenge_id, user_id), so claiming a solve twice conflicts
    instead of paying the bonus twice.
    """

    __tablename__ = "challenge_attempts"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    challenge_id = Column(
        UUID(as_uuid=True),
        ForeignKey("daily_challenges.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    is_solved = Column(Boolean, nullable=False, server_default="false")
    solved_at = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
