from pydantic import BaseModel
from typing import Any, Dict, List
from app.schemas.chat import Message


class ToolStep(BaseModel):
    """Planner ReAct siklidagi bitta tool chaqiruvi izi (trace)."""

    step: int
    tool: str
    args: Dict[str, Any]
    observation: str
    success: bool


class AgentRunRequest(BaseModel):
    message: str
    history: List[Message] = []
    session_id: str = "default"


class AgentRunResponse(BaseModel):
    reply: str
    agent_used: str
    model_used: str
    steps: List[ToolStep] = []
