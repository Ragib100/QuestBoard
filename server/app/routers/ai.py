from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies.auth import get_current_user_id
from app.models import HINT_COST
from app.schemas.ai import HintRequest, HintResponse, HintStatus
from app.services.ai_service import AiHintError, AiService

router = APIRouter(prefix="/ai", tags=["AI"])


@router.get("/hint", response_model=HintStatus)
def hint_status(
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    """What the hint button should say before anyone spends anything."""
    return HintStatus(
        available=AiService.is_configured(),
        points_cost=HINT_COST,
        hints_remaining=AiService.remaining_today(db, user_id),
    )


@router.post("/hint", response_model=HintResponse)
def create_hint(
    payload: HintRequest,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        text, remaining_points = AiService.hint(db, payload.question_id, user_id)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(e)
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail=str(e))
    except AiHintError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e)
        )

    return HintResponse(
        hint_text=text,
        points_cost=HINT_COST,
        points_remaining=remaining_points,
        hints_remaining=AiService.remaining_today(db, user_id),
    )
