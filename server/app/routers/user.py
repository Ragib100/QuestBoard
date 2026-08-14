from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies.auth import get_current_user_id
from app.schemas.user import (
    PointsResponse,
    UserCreate,
    UserResponse,
    UserUpdate,
)
from app.services.user_service import UserService

router = APIRouter(
    prefix="/users",
    tags=["Users"],
)


@router.post(
    "",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_user(
    user_data: UserCreate,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        return UserService.create_user(
            db=db,
            user_id=user_id,
            user_data=user_data,
        )

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get("/me", response_model=UserResponse)
def get_me(
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    """The signed-in user's own profile.

    Declared before /{user_id} so the literal path wins the route match.
    Returns 404 when authenticated but not yet onboarded, which is how the
    client knows to send someone to ProfileCreate.
    """
    try:
        return UserService.get(db=db, user_id=user_id)
    except LookupError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.get("/{user_id}", response_model=UserResponse)
def get_user(user_id: UUID, db: Session = Depends(get_db)):
    try:
        return UserService.get(db=db, user_id=user_id)
    except LookupError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )


@router.patch("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: UUID,
    user_data: UserUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
):
    if user_id != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only edit your own profile.",
        )

    try:
        return UserService.update(db=db, user_id=user_id, user_data=user_data)
    except LookupError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )


@router.get("/{user_id}/points", response_model=PointsResponse)
def get_points(
    user_id: UUID,
    db: Session = Depends(get_db),
    limit: int = 50,
):
    try:
        return UserService.points(db=db, user_id=user_id, limit=limit)
    except LookupError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
