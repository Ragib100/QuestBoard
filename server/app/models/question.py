from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Table,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.base import Base

question_tags = Table(
    "question_tags",
    Base.metadata,
    Column(
        "question_id",
        UUID(as_uuid=True),
        ForeignKey("questions.id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "tag_id",
        UUID(as_uuid=True),
        ForeignKey("tags.id", ondelete="CASCADE"),
        primary_key=True,
    ),
)


class Tag(Base):
    __tablename__ = "tags"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    name = Column(String(50), nullable=False, unique=True)


class Question(Base):
    """A quest: a question carrying a point bounty.

    The table is named `questions` for historical reasons — the product calls it
    a quest and the UI says so, but the schema and every foreign key that points
    at it use `question`. Do not rename one without the other.
    """

    __tablename__ = "questions"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=func.gen_random_uuid(),
    )
    author_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    title = Column(Text, nullable=False)
    body = Column(Text, nullable=False)
    image_url = Column(Text)
    bounty_points = Column(Integer, nullable=False, server_default="0")
    is_solved = Column(Boolean, nullable=False, server_default="false")
    accepted_answer_id = Column(
        UUID(as_uuid=True),
        ForeignKey("answers.id", ondelete="SET NULL"),
    )
    view_count = Column(Integer, nullable=False, server_default="0")
    difficulty = Column(String(10))
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    author = relationship("User", back_populates="questions")
    tags = relationship("Tag", secondary=question_tags, lazy="selectin")
    answers = relationship(
        "Answer",
        back_populates="question",
        foreign_keys="Answer.question_id",
        cascade="all, delete-orphan",
    )
