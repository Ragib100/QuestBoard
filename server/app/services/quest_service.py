from uuid import UUID

from sqlalchemy.orm import Session

from app.models.quest import Quest
from app.models.user import User
from app.schemas.quest import QuestCreate


class QuestService:
    @staticmethod
    def create_quest(db: Session, user_id: UUID, quest_data: QuestCreate) -> Quest:
        # A verified Supabase account is not enough — quests.user_id references
        # public.users, which is only populated once onboarding completes.
        author = db.query(User).filter(User.id == user_id).first()

        if author is None:
            raise ValueError("Complete your profile before posting a quest.")

        db_quest = Quest(
            **quest_data.model_dump(),
            user_id=user_id,
        )

        try:
            db.add(db_quest)
            db.commit()
            db.refresh(db_quest)
        except Exception:
            db.rollback()
            raise

        return db_quest
