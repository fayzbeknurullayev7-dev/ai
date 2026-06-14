from pydantic import BaseModel
from typing import List, Optional


class Message(BaseModel):
    role: str  # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    message: str
    history: List[Message] = []
    session_id: str = "default"
    # Tabga bog'liq agentni majburlash: "image" | "code" | "media" | "planner".
    # None bo'lsa — keyword routing (default xulq) ishlaydi.
    mode: Optional[str] = None


class ChatResponse(BaseModel):
    reply: str
    agent_used: str
    model_used: str
