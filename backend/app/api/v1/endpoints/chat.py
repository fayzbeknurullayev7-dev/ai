from fastapi import APIRouter, Depends, HTTPException
from app.agents.router import AgentRouter
from app.core.dependencies import get_agent_router, get_current_user
from app.auth import User
from app.schemas.chat import ChatRequest, ChatResponse
from app.api.sse import sse_response

router = APIRouter()


@router.post("/", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    agent_router: AgentRouter = Depends(get_agent_router),
    current: User = Depends(get_current_user),
):
    # Sessiya = joriy foydalanuvchi id'si: har kim o'z xotirasi/bilim bazasiga ega.
    try:
        result = await agent_router.route(
            request.message, request.history, current.id
        )
        return ChatResponse(
            reply=result.content,
            agent_used=result.agent_name,
            model_used=result.model_name,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/stream")
async def chat_stream(
    request: ChatRequest,
    agent_router: AgentRouter = Depends(get_agent_router),
    current: User = Depends(get_current_user),
):
    """Keyword routing bilan tanlangan agentni tipizatsiyalangan SSE oqimida."""
    return sse_response(
        agent_router.route_stream_events(
            request.message, request.history, current.id
        )
    )
