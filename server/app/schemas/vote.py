from typing import Literal

from pydantic import BaseModel, Field


class VoteRequest(BaseModel):
    value: Literal[-1, 1] = Field(description="1 to upvote, -1 to downvote")


class VoteResponse(BaseModel):
    vote_count: int
    my_vote: int
