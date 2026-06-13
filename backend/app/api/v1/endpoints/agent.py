from fastapi import APIRouter, Depends, HTTPException

from app.agents.planner_agent import PlannerAgent
from app.core.dependencies import (
    get_planner,
    get_memory,
    get_tool_registry,
    get_current_user,
)
from app.auth import User
from app.memory.base_memory import BaseMemory
from app.tools.registry import ToolRegistry
from app.schemas.agent import AgentRunRequest, AgentRunResponse, ToolStep
from app.api.sse import sse_response

router = APIRouter()


@router.post("/run", response_model=AgentRunResponse)
async def run_agent(
    request: AgentRunRequest,
    planner: PlannerAgent = Depends(get_planner),
    current: User = Depends(get_current_user),
):
    """Planner Agent'ni ishga tushiradi — ReAct sikli + tool'lar + xotira.

    Sessiya = joriy foydalanuvchi id'si (xotira va RAG izolyatsiyasi).
    """
    try:
        result = await planner.process(
            request.message, request.history, current.id
        )
        return AgentRunResponse(
            reply=result.content,
            agent_used=result.agent_name,
            model_used=result.model_name,
            steps=[ToolStep(**s) for s in result.steps],
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/stream")
async def run_agent_stream(
    request: AgentRunRequest,
    planner: PlannerAgent = Depends(get_planner),
    current: User = Depends(get_current_user),
):
    """Planner Agent'ni real vaqt SSE oqimida — qadamlar bajarilishi bilanoq."""
    return sse_response(
        planner.stream_events(
            request.message, request.history, current.id
        )
    )


@router.get("/tools")
async def list_tools(
    registry: ToolRegistry = Depends(get_tool_registry),
    current: User = Depends(get_current_user),
):
    """Ro'yxatdan o'tgan barcha tool'lar va ularning sxemasi."""
    return {"tools": registry.schemas()}


@router.get("/memory")
async def get_memory_state(
    memory: BaseMemory = Depends(get_memory),
    current: User = Depends(get_current_user),
):
    """Joriy foydalanuvchi xotirasi: saqlangan faktlar va suhbat tarixi uzunligi."""
    facts = await memory.get_facts(current.id)
    history = await memory.get_history(current.id)
    return {
        "session_id": current.id,
        "facts": facts,
        "history_length": len(history),
    }


@router.delete("/memory")
async def clear_memory(
    memory: BaseMemory = Depends(get_memory),
    current: User = Depends(get_current_user),
):
    """Joriy foydalanuvchi xotirasini tozalaydi."""
    await memory.clear(current.id)
    return {"status": "cleared", "session_id": current.id}
