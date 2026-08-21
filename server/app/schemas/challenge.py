from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.schemas.code import CodeSubmission
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
    # Codeforces' own submit form for this problem. Computed, never stored —
    # like `award_points`, it is derived from `codeforces_id`.
    submit_url: str | None = None
    # The challenge's value on its own day. What a solve pays *now* is
    # `award_points`, which is this decayed by age — see docs/api.md.
    bonus_points: int
    challenge_date: date

    # Computed per request, never stored: a stored copy is wrong by morning.
    award_points: int = 0
    age_days: int = 0


class AttemptResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    is_solved: bool
    solved_at: datetime | None
    # What this solve actually paid — 0 on an unsolved attempt, and lower than
    # the challenge's `bonus_points` when it was claimed late.
    awarded_points: int = 0
    code_body: str | None = None
    code_language: str | None = None
    attachment_url: str | None = None
    attachment_name: str | None = None


class ChallengeView(BaseModel):
    """One challenge plus everything the screen needs to say what the viewer
    can do with it. Today's challenge and an archived one use the same shape,
    which is what lets one screen render both."""

    challenge: ChallengeResponse
    # False when Codeforces was unreachable and the server fell back to the
    # last challenge we stored — the client says so rather than mislabelling it.
    is_today: bool
    solver_count: int
    # Null for signed-out callers, and for anyone who has not tried yet.
    my_attempt: AttemptResponse | None = None
    # Whether the caller can claim at all: claiming needs a verified handle.
    codeforces_verified: bool = False


# The name the client has used since M4. Kept so `/challenges/today` does not
# change shape just because archived challenges now share it.
TodayResponse = ChallengeView


class ChallengePage(BaseModel):
    items: list[ChallengeView]
    page: int
    limit: int
    total: int
    has_more: bool


class SolveRequest(CodeSubmission):
    """Claiming a challenge, optionally submitting the solution with it.

    Every field is optional: the bonus is paid on the Codeforces verdict, so a
    claim with no code is still a valid claim.
    """


class StatementSample(BaseModel):
    """One worked example from the statement."""

    input: str
    output: str


class ProblemStatement(BaseModel):
    """`GET /challenges/{id}/statement`.

    `available` is false whenever Codeforces would not give us the page — which
    is a routine outcome, not an error, so this is a 200 with an honest flag
    rather than a 502. The client falls back to the challenge's own summary.
    """

    available: bool
    html: str = ""
    time_limit: str = ""
    memory_limit: str = ""
    samples: list[StatementSample] = []
    source_url: str | None = None
    submit_url: str | None = None


class ChallengeSolver(BaseModel):
    rank: int
    solved_at: datetime | None
    awarded_points: int = 0
    user: UserSummary


class VerificationChallenge(BaseModel):
    """Instructions for proving you own a Codeforces handle."""

    handle: str
    codeforces_id: str
    problem_url: str
    # Where the deliberate compilation error actually gets submitted.
    submit_url: str
    window_minutes: int
