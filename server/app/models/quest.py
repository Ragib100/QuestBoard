from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import relationship

from app.db.base import Base


class Quest(Base):
    __tablename__ = "quests"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    title = Column(Text, nullable=False)
    description = Column(Text)
    tags = Column(ARRAY(String))
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    user = relationship("User", back_populates="quests")
