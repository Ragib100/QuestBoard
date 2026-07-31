from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class QuestBase(BaseModel):
    title: str
    description: Optional[str] = None
    tags: Optional[List[str]] = None


class QuestCreate(QuestBase):
    pass


class QuestResponse(QuestBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    user_id: UUID
