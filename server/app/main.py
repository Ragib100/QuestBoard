from fastapi import FastAPI

from app.db.base import Base
from app.db.database import engine

import app.db.models

from app.routers.temp_test import router

Base.metadata.create_all(bind=engine)

app = FastAPI()


@app.get("/")
def root():
    return {"message": "QuestBoard API is running!"}


app.include_router(router)
