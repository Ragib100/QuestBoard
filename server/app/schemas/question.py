from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.user import UserSummary

MAX_BOUNTY = 100


class QuestionCreate(BaseModel):
    title: str = Field(min_length=10, max_length=200)
    body: str = Field(min_length=20)
    tags: list[str] = Field(default_factory=list, max_length=5)
    bounty_points: int = Field(default=0, ge=0, le=MAX_BOUNTY)
    image_url: str | None = None


class QuestionUpdate(BaseModel):
    """Bounty is deliberately absent — it is spent at post time and cannot be
    edited afterwards without unwinding the ledger."""

    title: str | None = Field(default=None, min_length=10, max_length=200)
    body: str | None = Field(default=None, min_length=20)
    tags: list[str] | None = Field(default=None, max_length=5)
    image_url: str | None = None


class AnswerResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    question_id: UUID
    body: str
    image_url: str | None
    is_accepted: bool
    created_at: datetime
    author: UserSummary
    vote_count: int = 0
    my_vote: int = 0


class QuestionSummary(BaseModel):
    """Feed row — no body, no answers."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    bounty_points: int
    is_solved: bool
    view_count: int
    created_at: datetime
    author: UserSummary
    tags: list[str] = []
    answer_count: int = 0
    vote_count: int = 0


class QuestionDetail(QuestionSummary):
    body: str
    image_url: str | None
    accepted_answer_id: UUID | None
    my_vote: int = 0
    answers: list[AnswerResponse] = []


class QuestionPage(BaseModel):
    items: list[QuestionSummary]
    page: int
    limit: int
    total: int
    has_more: bool
