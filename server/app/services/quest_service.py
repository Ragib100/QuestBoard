from uuid import UUID

from sqlalchemy.orm import Session

from app.models.quest import Quest
from app.schemas.quest import QuestCreate


class QuestService:
    @staticmethod
    def create_quest(db: Session, user_id: UUID, quest_data: QuestCreate) -> Quest:
        db_quest = Quest(
            **quest_data.model_dump(),
            user_id=user_id,
        )
        db.add(db_quest)
        db.commit()
        db.refresh(db_quest)
        return db_quest
