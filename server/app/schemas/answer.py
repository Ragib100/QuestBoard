from pydantic import BaseModel, Field


class AnswerCreate(BaseModel):
    body: str = Field(min_length=10)
    image_url: str | None = None


class AnswerUpdate(BaseModel):
    body: str = Field(min_length=10)
    image_url: str | None = None
