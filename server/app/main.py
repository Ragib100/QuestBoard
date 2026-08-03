from uuid import UUID

from fastapi import APIRouter, Depends, FastAPI

from app.dependencies.auth import get_current_user_id
from app.routers.user import router as user_router
from app.routers.quest import router as quest_router

app = FastAPI(title="QuestBoard API", version="0.1.0")


@app.get("/api/")
def root():
    return {"message": "QuestBoard API is running!"}


api_router = APIRouter(prefix="/api")
api_router.include_router(user_router)
api_router.include_router(quest_router)


@api_router.get("/ping")
def ping(user_id: UUID = Depends(get_current_user_id)):
    return {"user_id": str(user_id)}


app.include_router(api_router)
