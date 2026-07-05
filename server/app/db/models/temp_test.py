from sqlalchemy.orm import Mapped
from sqlalchemy.orm import mapped_column

from app.db.base import Base


class TempTest(Base):
    __tablename__ = "temp_test"

    id: Mapped[int] = mapped_column(primary_key=True)

    name: Mapped[str]
