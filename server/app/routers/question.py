from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies.auth import get_current_user_id, get_optional_user_id
from app.models import TARGET_QUESTION
from app.schemas.answer import AnswerCreate
from app.schemas.question import (
    QuestionCreate,
    QuestionDetail,
    QuestionPage,
    QuestionUpdate,
)
from app.schemas.vote import VoteRequest, VoteResponse
from app.services.answer_service import AnswerService
from app.services.question_service import QuestionService
from app.services.vote_service import VoteService
from app.utils.serialize import answer_payload, question_detail, question_summary

router = APIRouter(prefix="/questions", tags=["Quests"])


@router.get("", response_model=QuestionPage)
def list_questions(
    db: Session = Depends(get_db),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    tag: str | None = None,
    sort: str = Query("latest", pattern="^(latest|bounty|votes)$"),
    search: str | None = None,
):
    items, total = QuestionService.list_page(
        db, page=page, limit=limit, tag=tag, sort=sort, search=search
    )
    return QuestionPage(
        items=[question_summary(i) for i in items],
        page=page,
        limit=limit,
        total=total,
        has_more=page * limit < total,
    )


@router.post("", response_model=QuestionDetail, status_code=status.HTTP_201_CREATED)
def create_question(
    data: QuestionCreate,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        question = QuestionService.create(db, user_id, data)
    except ValueError as e:
        # A bounty the author cannot afford is a payment problem, not a typo.
        code = (
            status.HTTP_402_PAYMENT_REQUIRED
            if "points" in str(e).lower()
            else status.HTTP_400_BAD_REQUEST
        )
        raise HTTPException(status_code=code, detail=str(e))

    return question_detail(QuestionService.enrich(db, question, user_id))


@router.get("/{question_id}", response_model=QuestionDetail)
def get_question(
    question_id: UUID,
    db: Session = Depends(get_db),
    viewer_id: UUID | None = Depends(get_optional_user_id),
):
    try:
        question = QuestionService.get(db, question_id, count_view=True)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

    return question_detail(QuestionService.enrich(db, question, viewer_id))


@router.patch("/{question_id}", response_model=QuestionDetail)
def update_question(
    question_id: UUID,
    data: QuestionUpdate,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        question = QuestionService.update(db, question_id, user_id, data)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    return question_detail(QuestionService.enrich(db, question, user_id))


@router.delete("/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_question(
    question_id: UUID,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        QuestionService.delete(db, question_id, user_id)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{question_id}/answers",
    status_code=status.HTTP_201_CREATED,
)
def create_answer(
    question_id: UUID,
    data: AnswerCreate,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        answer = AnswerService.create(db, question_id, user_id, data)
    except LookupError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))

    return answer_payload({"answer": answer, "vote_count": 0, "my_vote": 0})


@router.post("/{question_id}/vote", response_model=VoteResponse)
def vote_question(
    question_id: UUID,
    data: VoteRequest,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    try:
        count, mine = VoteService.cast(
            db, user_id, TARGET_QUESTION, question_id, data.value
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
