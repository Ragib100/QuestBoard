from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def root():
    return {"message": "QuestBoard API is running!"}
