from pydantic import BaseModel


class TempTestCreate(BaseModel):
    name: str
