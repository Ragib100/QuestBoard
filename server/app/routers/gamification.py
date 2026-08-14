from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies.auth import get_current_user_id, get_optional_user_id
from app.schemas.gamification import (
    BadgeResponse,
    LeaderboardEntry,
    LeaderboardResponse,
    NotificationPage,
    NotificationResponse,
)
from app.schemas.user import UserSummary
from app.services.badge_service import BadgeService
from app.services.leaderboard_service import LeaderboardService
from app.services.notification_service import NotificationService

router = APIRouter(tags=["Gamification"])


def _entry(row: dict) -> LeaderboardEntry:
    return LeaderboardEntry(
        rank=row["rank"] or 0,
        score=row["score"],
        user=UserSummary.model_validate(row["user"]),
    )


@router.get("/leaderboard", response_model=LeaderboardResponse)
def leaderboard(
    db: Session = Depends(get_db),
    period: str = Query("all_time", pattern="^(weekly|all_time)$"),
    limit: int = Query(20, ge=1, le=50),
    viewer_id: UUID | None = Depends(get_optional_user_id),
):
    """Public. Signed-in callers also get their own rank pinned."""
    rows = LeaderboardService.top(db, period=period, limit=limit)

    me = None
    if viewer_id is not None:
        mine = LeaderboardService.rank_of(db, viewer_id, period=period)
        if mine is not None:
            me = _entry(mine)

    return LeaderboardResponse(
        period=period,
        entries=[_entry(r) for r in rows],
        me=me,
    )


@router.get("/badges", response_model=list[BadgeResponse])
def badge_catalogue(db: Session = Depends(get_db)):
    """Every badge that exists, earned or not."""
    return BadgeService.catalogue(db)


@router.get("/notifications", response_model=NotificationPage)
def list_notifications(
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
    page: int = Query(1, ge=1),
    limit: int = Query(30, ge=1, le=100),
):
    items, _ = NotificationService.list_for(db, user_id, page=page, limit=limit)
    return NotificationPage(
        items=[NotificationResponse.model_validate(n) for n in items],
        unread_count=NotificationService.unread_count(db, user_id),
    )


@router.get("/notifications/unread-count")
def unread_count(
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    """Cheap poll for the nav bell — one COUNT, no rows."""
    return {"unread_count": NotificationService.unread_count(db, user_id)}


@router.patch("/notifications/read-all")
def mark_all_read(
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    return {"marked": NotificationService.mark_all_read(db, user_id)}


@router.patch(
    "/notifications/{notification_id}/read", response_model=NotificationResponse
)
def mark_read(
    notification_id: UUID,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        return NotificationService.mark_read(db, notification_id, user_id)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
