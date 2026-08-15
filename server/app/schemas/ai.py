from uuid import UUID

from pydantic import BaseModel


class HintRequest(BaseModel):
    question_id: UUID


class HintResponse(BaseModel):
    hint_text: str
    points_cost: int
    points_remaining: int
    # Hints left in the current hour, so the client can disable the button
    # before the user pays for a 429.
    hints_remaining: int


class HintStatus(BaseModel):
    """What the client needs to render the hint button honestly."""

    available: bool
    points_cost: int
    hints_remaining: int
