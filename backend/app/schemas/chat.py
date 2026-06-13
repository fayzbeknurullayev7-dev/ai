from pydantic import BaseModel
from typing import List


class Message(BaseModel):
    role: str  # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    message: str
    history: List[Message] = []
    session_id: str = "default"


class ChatResponse(BaseModel):
    reply: str
    agent_used: str
    model_used: str
