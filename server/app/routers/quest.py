from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies.auth import get_current_user_id
from app.schemas.quest import QuestCreate, QuestResponse
from app.services.quest_service import QuestService

router = APIRouter(
    prefix="/quests",
    tags=["Quests"],
)


@router.post(
    "",
    response_model=QuestResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_quest(
    quest_data: QuestCreate,
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
):
    return QuestService.create_quest(db=db, user_id=user_id, quest_data=quest_data)
