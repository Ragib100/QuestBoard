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
from app.schemas.challenge import VerificationChallenge
from app.schemas.gamification import EarnedBadge, StreakResponse
from app.services import codeforces_service as cf
from app.services.badge_service import BadgeService
from app.services.user_service import UserService

router = APIRouter(
    prefix="/users",
    tags=["Users"],
)


def _own_profile(db: Session, user_id: UUID):
    try:
        return UserService.get(db=db, user_id=user_id)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


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


@router.get("/me/codeforces/verification", response_model=VerificationChallenge)
def codeforces_verification(
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    """What to submit to prove the handle on your profile is yours.

    Reading a handle back from the Codeforces API only proves the handle
    exists, not who typed it into our form — but only the account's owner can
    put a submission on it. So we name a problem and ask for a deliberate
    compilation error, which is harmless and unambiguous.
    """
    user = _own_profile(db, user_id)
    handle = user.codeforces_handle.strip()
    if not handle:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Add your Codeforces handle to your profile first.",
        )

    try:
        problem = cf.verification_problem(str(user_id))
    except cf.CodeforcesError as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(e))

    codeforces_id = f"{problem['contestId']}/{problem['index']}"
    return VerificationChallenge(
        handle=handle,
        codeforces_id=codeforces_id,
        problem_url=cf.problem_url(codeforces_id),
        window_minutes=int(cf.VERIFICATION_WINDOW.total_seconds() // 60),
    )


@router.post("/me/codeforces/verification", response_model=UserResponse)
def confirm_codeforces_verification(
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    """Checks Codeforces for the compilation error and marks the handle verified."""
    user = _own_profile(db, user_id)
    handle = user.codeforces_handle.strip()
    if not handle:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Add your Codeforces handle to your profile first.",
        )

    try:
        problem = cf.verification_problem(str(user_id))
        codeforces_id = f"{problem['contestId']}/{problem['index']}"
        proved = cf.has_compile_error(handle, codeforces_id)
    except cf.CodeforcesError as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(e))

    if not proved:
        minutes = int(cf.VERIFICATION_WINDOW.total_seconds() // 60)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"No compilation error from {handle} on problem {codeforces_id} "
                f"in the last {minutes} minutes. Submit one, then try again."
            ),
        )

    user.codeforces_verified = True
    db.commit()
    db.refresh(user)
    return user


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


@router.get("/{user_id}/badges", response_model=list[EarnedBadge])
def get_badges(user_id: UUID, db: Session = Depends(get_db)):
    try:
        UserService.get(db=db, user_id=user_id)
    except LookupError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )

    return [
        EarnedBadge(
            id=ub.badge.id,
            name=ub.badge.name,
            description=ub.badge.description,
            icon_url=ub.badge.icon_url,
            awarded_at=ub.awarded_at,
        )
        for ub in BadgeService.for_user(db=db, user_id=user_id)
    ]


@router.get("/{user_id}/streak", response_model=StreakResponse)
def get_streak(user_id: UUID, db: Session = Depends(get_db)):
    try:
        user = UserService.get(db=db, user_id=user_id)
    except LookupError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )

    return StreakResponse(streak_days=user.streak_days, last_active=user.last_active)
