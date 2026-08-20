from datetime import date

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

from app.core import clock
from app.db.base import Base

CHALLENGE_BONUS = 50

# How a challenge loses value as it ages. Past challenges stay solvable — the
# archive is there to be worked through — but a problem everyone has had a week
# to look up cannot be worth the same as today's.
#
# The award drops by DECAY_PER_DAY of the *base* per day (so it falls in equal
# steps, not exponentially) and stops at DECAY_FLOOR of the base. The floor is
# what keeps an old challenge worth attempting at all.
DECAY_PER_DAY = 0.10
DECAY_FLOOR = 0.20


def award_for(bonus_points: int, challenge_date: date, on: date | None = None) -> int:
    """What solving a challenge of that date is worth on day `on` (Dhaka today).

    Pure and deterministic: the decayed value is never stored on the challenge,
    because a stored copy would be wrong by the next morning. The amount that
    *is* stored is what a specific solve paid — `challenge_attempts.awarded_points`.
    """
    if bonus_points <= 0:
        return 0

    today = on or clock.today()
    age_days = max(0, (today - challenge_date).days)

    floor = max(1, round(bonus_points * DECAY_FLOOR))
    decayed = bonus_points - round(bonus_points * DECAY_PER_DAY * age_days)
    return max(floor, decayed)


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
    # What this solve actually paid. `bonus_points` is the challenge's value on
    # its own day; a late solver gets less, and only this column remembers that.
    awarded_points = Column(Integer, nullable=False, server_default="0")
    # The solution submitted through the app. The bonus is still paid on a
    # verified Codeforces verdict — this is the record of the work, not proof.
    code_body = Column(Text)
    code_language = Column(String(20))
    attachment_url = Column(Text)
    attachment_name = Column(Text)
    solved_at = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
