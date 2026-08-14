from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.schemas.user import UserSummary


class BadgeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    description: str
    icon_url: str | None = None


class EarnedBadge(BadgeResponse):
    awarded_at: datetime


class LeaderboardEntry(BaseModel):
    rank: int
    score: int
    user: UserSummary


class LeaderboardResponse(BaseModel):
    period: str
    entries: list[LeaderboardEntry]
    # The caller's own standing, so it can be pinned even when outside the top.
    # `rank` is null when they have earned nothing in the period.
    me: LeaderboardEntry | None = None


class StreakResponse(BaseModel):
    streak_days: int
    last_active: datetime | None


class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    type: str
    message: str
    reference_id: UUID | None
    is_read: bool
    created_at: datetime


class NotificationPage(BaseModel):
    items: list[NotificationResponse]
    unread_count: int
