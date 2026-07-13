from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Integer,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import UUID

from app.db.base import Base


class User(Base):
    __tablename__ = "users"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
    )

    username = Column(String, unique=True, nullable=False)

    first_name = Column(
        String,
        nullable=False,
        server_default="",
    )

    last_name = Column(
        String,
        nullable=False,
        server_default="",
    )

    phone_number = Column(
        String,
        nullable=True,
    )

    image_url = Column(
        String,
        nullable=False,
        server_default="",
    )

    codeforces_handle = Column(
        String,
        nullable=False,
        server_default="",
    )

    codeforces_verified = Column(
        Boolean,
        nullable=False,
        server_default="false",
    )

    points = Column(
        Integer,
        nullable=False,
        server_default="100",
    )

    streak_days = Column(
        Integer,
        nullable=False,
        server_default="0",
    )

    last_active = Column(
        DateTime(timezone=True),
        nullable=True,
    )

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
