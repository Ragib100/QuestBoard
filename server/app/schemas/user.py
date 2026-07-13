from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=30)
    first_name: str = Field(default="", max_length=100)
    last_name: str = Field(default="", max_length=100)
    phone_number: str | None = Field(default=None, max_length=20)
    image_url: str
    codeforces_handle: str = ""


class UserUpdate(BaseModel):
    username: str | None = Field(default=None, max_length=30)
    first_name: str | None = Field(default=None, max_length=100)
    last_name: str | None = Field(default=None, max_length=100)
    phone_number: str | None = Field(default=None, max_length=20)
    image_url: str | None = None
    codeforces_handle: str | None = None
    codeforces_verified: bool | None = None


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    username: str
    first_name: str
    last_name: str
    phone_number: str | None

    image_url: str

    codeforces_handle: str
    codeforces_verified: bool

    points: int
    streak_days: int

    last_active: datetime | None

    created_at: datetime
    updated_at: datetime
