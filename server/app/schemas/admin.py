from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class AdminStats(BaseModel):
    """Counts for the admin dashboard. Every number is a live COUNT/SUM —
    nothing here is estimated or cached."""

    total_users: int
    suspended_users: int
    total_quests: int
    open_quests: int
    total_answers: int
    points_in_circulation: int


class AdminUser(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    username: str
    first_name: str
    last_name: str
    image_url: str
    points: int
    is_admin: bool
    is_suspended: bool
    created_at: datetime


class AdminUserPage(BaseModel):
    items: list[AdminUser]
    page: int
    limit: int
    total: int
    has_more: bool


class SuspendRequest(BaseModel):
    """Explicit rather than a toggle, so two admins acting at once cannot
    flip each other's decision back."""

    suspended: bool
