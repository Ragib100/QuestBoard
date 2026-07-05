from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models import TempTest
from app.schemas.temp_test import TempTestCreate

router = APIRouter()


@router.post("/api/temp_test")
def temp_test(
    payload: TempTestCreate,
    db: Session = Depends(get_db),
):
    row = TempTest(name=payload.name)

    db.add(row)
    db.commit()
    db.refresh(row)

    return {
        "id": row.id,
        "name": row.name,
    }
