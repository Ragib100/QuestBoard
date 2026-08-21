from uuid import UUID

from fastapi import APIRouter, Body, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core import clock
from app.db.database import get_db
from app.dependencies.auth import get_current_user_id, get_optional_user_id
from app.models import User
from app.schemas.challenge import (
    AttemptResponse,
    ChallengePage,
    ChallengeSolver,
    ChallengeView,
    SolveRequest,
    TodayResponse,
)
from app.schemas.code import CodeSubmission
from app.schemas.user import UserSummary
from app.services.challenge_service import ChallengeService
from app.utils.serialize import challenge_view

router = APIRouter(prefix="/challenges", tags=["Daily challenge"])


def _today_here():
    """The day the *viewer* is in. Ages and decay are counted in Dhaka days."""
    return clock.today()


def _viewer_is_verified(db: Session, viewer_id: UUID | None) -> bool:
    if viewer_id is None:
        return False
    user = db.get(User, viewer_id)
    return bool(user and user.codeforces_verified)


@router.get("/today", response_model=TodayResponse)
def today(
    db: Session = Depends(get_db),
    viewer_id: UUID | None = Depends(get_optional_user_id),
):
    """Public. Signed-in callers also get their own attempt state."""
    try:
        challenge = ChallengeService.today(db)
    except LookupError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e)
        )

    attempt = (
        ChallengeService.attempt_of(db, challenge.id, viewer_id)
        if viewer_id is not None
        else None
    )

    return challenge_view(
        challenge,
        today=_today_here(),
        attempt=attempt,
        solver_count=ChallengeService.solver_count(db, challenge.id),
        codeforces_verified=_viewer_is_verified(db, viewer_id),
    )


@router.get("", response_model=ChallengePage)
def archive(
    db: Session = Depends(get_db),
    viewer_id: UUID | None = Depends(get_optional_user_id),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    include_today: bool = False,
):
    """Public. Past challenges, newest first.

    Every row carries `award_points` — what solving it is worth *now*, after the
    age decay — so the archive never advertises a number it will not pay.
    """
    rows, total = ChallengeService.archive_page(
        db,
        page=page,
        limit=limit,
        include_today=include_today,
        viewer_id=viewer_id,
    )

    verified = _viewer_is_verified(db, viewer_id)
    today_here = _today_here()

    return ChallengePage(
        items=[
            challenge_view(
                row["challenge"],
                today=today_here,
                attempt=row["attempt"],
                solver_count=row["solver_count"],
                codeforces_verified=verified,
            )
            for row in rows
        ],
        page=page,
        limit=limit,
        total=total,
        has_more=page * limit < total,
    )


@router.get("/{challenge_id}", response_model=ChallengeView)
def one(
    challenge_id: UUID,
    db: Session = Depends(get_db),
    viewer_id: UUID | None = Depends(get_optional_user_id),
):
    """Public. The same shape as `/today`, so one screen renders both."""
    try:
        challenge = ChallengeService.get(db, challenge_id)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

    attempt = (
        ChallengeService.attempt_of(db, challenge.id, viewer_id)
        if viewer_id is not None
        else None
    )

    return challenge_view(
        challenge,
        today=_today_here(),
        attempt=attempt,
        solver_count=ChallengeService.solver_count(db, challenge.id),
        codeforces_verified=_viewer_is_verified(db, viewer_id),
    )


@router.post("/{challenge_id}/solve", response_model=AttemptResponse)
def solve(
    challenge_id: UUID,
    data: SolveRequest = Body(default_factory=SolveRequest),
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    """Claims the award, after checking Codeforces for an accepted submission.

    The body is optional: it carries the solution written or uploaded in the
    app, which is stored on the attempt whether or not the verdict has landed.
    """
    try:
        return ChallengeService.claim(db, challenge_id, user_id, data)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(e))


@router.put("/{challenge_id}/submission", response_model=AttemptResponse)
def save_submission(
    challenge_id: UUID,
    data: CodeSubmission = Body(default_factory=CodeSubmission),
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    """Stores the caller's code on their attempt. Codeforces is never called.

    Separate from `/solve` because saving your work and claiming the bonus are
    separate acts. `/solve` refuses without an accepted verdict upstream, so
    when it was the only writer there was no way to submit code before solving.
    """
    try:
        return ChallengeService.save_submission(db, challenge_id, user_id, data)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.get("/{challenge_id}/leaderboard", response_model=list[ChallengeSolver])
def leaderboard(
    challenge_id: UUID,
    db: Session = Depends(get_db),
    limit: int = Query(50, ge=1, le=100),
):
    return [
        ChallengeSolver(
            rank=row["rank"],
            solved_at=row["solved_at"],
            awarded_points=row["awarded_points"],
            user=UserSummary.model_validate(row["user"]),
        )
        for row in ChallengeService.leaderboard(db, challenge_id, limit=limit)
    ]
