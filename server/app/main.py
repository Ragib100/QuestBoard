from uuid import UUID

from fastapi import APIRouter, Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.dependencies.auth import get_current_user_id
from app.routers.ai import router as ai_router
from app.routers.answer import router as answer_router
from app.routers.challenge import router as challenge_router
from app.routers.gamification import router as gamification_router
from app.routers.question import router as question_router
from app.routers.user import router as user_router

app = FastAPI(title="QuestBoard API", version="0.1.0")

# Flutter web runs in a browser, so it is blocked by CORS unless the API opts in.
# Android, desktop and the Flutter test harness are unaffected either way.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/")
def root():
    """Liveness check. Also what uptime pings and Render health checks hit."""
    return {"message": "QuestBoard API is running!"}


api_router = APIRouter(prefix="/api")
api_router.include_router(user_router)
api_router.include_router(question_router)
api_router.include_router(answer_router)
api_router.include_router(gamification_router)
api_router.include_router(challenge_router)
api_router.include_router(ai_router)


@api_router.get("/ping")
def ping(user_id: UUID = Depends(get_current_user_id)):
    """Verifies a Supabase token end to end — returns the caller's user id."""
    return {"user_id": str(user_id)}


app.include_router(api_router)
