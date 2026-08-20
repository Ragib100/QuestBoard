from sqlalchemy.orm import relationship
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


# What a new account starts with. Mirrored by the column's server default so a
# row inserted directly in SQL still gets it — but the API hands it out through
# PointService, so the ledger has a `signup_bonus` row to explain the balance.
SIGNUP_BONUS = 100


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
        server_default=str(SIGNUP_BONUS),
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

    is_admin = Column(
        Boolean,
        nullable=False,
        server_default="false",
    )

    # Set by an admin. A suspended account can still read — banning someone
    # from a Q&A board they may be cited in helps nobody — but cannot post,
    # answer or vote. Enforced in the services, not in the JWT dependency,
    # because the token knows nothing about this column.
    is_suspended = Column(
        Boolean,
        nullable=False,
        server_default="false",
    )

    questions = relationship("Question", back_populates="author")
    answers = relationship("Answer", back_populates="author")
