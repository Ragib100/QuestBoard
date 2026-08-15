from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies.admin import require_admin
from app.models import User
from app.schemas.admin import (
    AdminStats,
    AdminUser,
    AdminUserPage,
    SuspendRequest,
)
from app.services.admin_service import AdminService

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/stats", response_model=AdminStats)
def stats(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    return AdminService.stats(db)


@router.get("/users", response_model=AdminUserPage)
def list_users(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    search: str | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    users, total = AdminService.list_users(db, page=page, limit=limit, search=search)
    return AdminUserPage(
        items=[AdminUser.model_validate(u) for u in users],
        page=page,
        limit=limit,
        total=total,
        has_more=page * limit < total,
    )


@router.patch("/users/{user_id}/suspend", response_model=AdminUser)
def suspend(
    user_id: UUID,
    data: SuspendRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    try:
        return AdminService.set_suspended(db, user_id, admin.id, data.suspended)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))


@router.delete("/quests/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_quest(
    question_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    try:
        AdminService.delete_quest(db, question_id)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
