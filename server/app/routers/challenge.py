from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies.auth import get_current_user_id, get_optional_user_id
from app.models import User
from app.schemas.challenge import (
    AttemptResponse,
    ChallengeResponse,
    ChallengeSolver,
    TodayResponse,
)
from app.schemas.user import UserSummary
from app.services.challenge_service import ChallengeService

router = APIRouter(prefix="/challenges", tags=["Daily challenge"])


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

    attempt = None
    verified = False
    if viewer_id is not None:
        row = ChallengeService.attempt_of(db, challenge.id, viewer_id)
        attempt = AttemptResponse.model_validate(row) if row is not None else None
        user = db.get(User, viewer_id)
        verified = bool(user and user.codeforces_verified)

    return TodayResponse(
        challenge=ChallengeResponse.model_validate(challenge),
        is_today=challenge.challenge_date == datetime.now(timezone.utc).date(),
        solver_count=ChallengeService.solver_count(db, challenge.id),
        my_attempt=attempt,
        codeforces_verified=verified,
    )


@router.post("/{challenge_id}/solve", response_model=AttemptResponse)
def solve(
    challenge_id: UUID,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    """Claims the bonus, after checking Codeforces for an accepted submission."""
    try:
        return ChallengeService.claim(db, challenge_id, user_id)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(e))


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
            user=UserSummary.model_validate(row["user"]),
        )
        for row in ChallengeService.leaderboard(db, challenge_id, limit=limit)
    ]
