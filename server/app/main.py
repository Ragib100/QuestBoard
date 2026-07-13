from fastapi import FastAPI, APIRouter

from app.db.base import Base
from app.db.database import engine

import app.models

from app.routers.user import router as user_router

Base.metadata.create_all(bind=engine)

app = FastAPI()


@app.get("/api/")
def root():
    return {"message": "QuestBoard API is running!"}


api_router = APIRouter(prefix="/api")
api_router.include_router(user_router)
app.include_router(api_router)
