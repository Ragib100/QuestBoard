from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.schemas.user import UserSummary


class ChallengeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    codeforces_id: str | None
    title: str
    body: str
    cf_rating: int | None
    difficulty: str | None
    source_url: str | None
    bonus_points: int
    challenge_date: date


class AttemptResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    is_solved: bool
    solved_at: datetime | None


class TodayResponse(BaseModel):
    challenge: ChallengeResponse
    # False when Codeforces was unreachable and we fell back to the last
    # challenge we stored — the client says so rather than mislabelling it.
    is_today: bool
    solver_count: int
    # Null for signed-out callers, and for anyone who has not tried yet.
    my_attempt: AttemptResponse | None = None
    # Whether the caller can claim at all: claiming needs a verified handle.
    codeforces_verified: bool = False


class ChallengeSolver(BaseModel):
    rank: int
    solved_at: datetime | None
    user: UserSummary


class VerificationChallenge(BaseModel):
    """Instructions for proving you own a Codeforces handle."""

    handle: str
    codeforces_id: str
    problem_url: str
    window_minutes: int
