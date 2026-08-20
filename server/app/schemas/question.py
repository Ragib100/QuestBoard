from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.user import UserSummary

MAX_BOUNTY = 100

# There is no *minimum* length on a quest any more: a short question is still a
# question, and the old 10/20-character floors mostly taught people to pad.
# Empty is still rejected — that is a mistake, not a style.
#
# The ceilings exist to stop a single request writing a megabyte into the
# table, not to shape what anyone writes, so they are far larger than any
# honest quest and the client never mentions them.
MAX_TITLE_CHARS = 300
MAX_BODY_CHARS = 50_000


def _required(value: str, field: str) -> str:
    text = value.strip()
    if not text:
        raise ValueError(f"{field} cannot be empty.")
    return text


class QuestionCreate(BaseModel):
    title: str = Field(max_length=MAX_TITLE_CHARS)
    body: str = Field(max_length=MAX_BODY_CHARS)
    tags: list[str] = Field(default_factory=list, max_length=5)
    bounty_points: int = Field(default=0, ge=0, le=MAX_BOUNTY)
    image_url: str | None = None

    @field_validator("title")
    @classmethod
    def _title_present(cls, value: str) -> str:
        return _required(value, "A title")

    @field_validator("body")
    @classmethod
    def _body_present(cls, value: str) -> str:
        return _required(value, "A description")


class QuestionUpdate(BaseModel):
    """Bounty is deliberately absent — it is spent at post time and cannot be
    edited afterwards without unwinding the ledger."""

    title: str | None = Field(default=None, max_length=MAX_TITLE_CHARS)
    body: str | None = Field(default=None, max_length=MAX_BODY_CHARS)
    tags: list[str] | None = Field(default=None, max_length=5)
    image_url: str | None = None

    # Omitting a field leaves it alone; sending it blank is an attempt to erase
    # it, and a quest with no title is not something we can render.
    @field_validator("title")
    @classmethod
    def _title_present(cls, value: str | None) -> str | None:
        return None if value is None else _required(value, "A title")

    @field_validator("body")
    @classmethod
    def _body_present(cls, value: str | None) -> str | None:
        return None if value is None else _required(value, "A description")


class AnswerResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    question_id: UUID
    body: str
    image_url: str | None
    # Null on a plain-prose answer; set when the helper submitted code or a file.
    code_body: str | None = None
    code_language: str | None = None
    attachment_url: str | None = None
    attachment_name: str | None = None
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
