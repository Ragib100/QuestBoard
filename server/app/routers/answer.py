from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies.auth import get_current_user_id
from app.models import TARGET_ANSWER
from app.schemas.answer import AnswerUpdate
from app.schemas.vote import VoteRequest, VoteResponse
from app.services.answer_service import AnswerService
from app.services.vote_service import VoteService
from app.utils.serialize import answer_payload

router = APIRouter(prefix="/answers", tags=["Answers"])


@router.patch("/{answer_id}")
def update_answer(
    answer_id: UUID,
    data: AnswerUpdate,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        answer = AnswerService.update(db, answer_id, user_id, data)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))

    count = VoteService.count_for(db, TARGET_ANSWER, answer.id)
    mine = VoteService.my_vote(db, user_id, TARGET_ANSWER, answer.id)
    return answer_payload({"answer": answer, "vote_count": count, "my_vote": mine})


@router.delete("/{answer_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_answer(
    answer_id: UUID,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        AnswerService.delete(db, answer_id, user_id)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{answer_id}/accept")
def accept_answer(
    answer_id: UUID,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        answer = AnswerService.accept(db, answer_id, user_id)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))

    count = VoteService.count_for(db, TARGET_ANSWER, answer.id)
    return answer_payload({"answer": answer, "vote_count": count, "my_vote": 0})


@router.post("/{answer_id}/vote", response_model=VoteResponse)
def vote_answer(
    answer_id: UUID,
    data: VoteRequest,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        count, mine = VoteService.cast(
            db, user_id, TARGET_ANSWER, answer_id, data.value
        )
        db.commit()
    except LookupError as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except ValueError as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    return VoteResponse(vote_count=count, my_vote=mine)
