from pydantic import BaseModel, Field


class UserRegister(BaseModel):
    username: str
    password: str


class MessageCreate(BaseModel):
    recipients: list[str] = Field(..., min_length=1)
    subject: str
    body: str