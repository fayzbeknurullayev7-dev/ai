from app.agents.router import AgentRouter
from app.agents.coder_agent import CoderAgent
from app.agents.media_agent import MediaAgent
from app.agents.planner_agent import PlannerAgent
from app.agents.image_agent import ImageAgent
from app.memory import BaseMemory, InMemoryStore, RedisMemory
from app.tools import build_default_registry, ToolRegistry
from app.tools.knowledge_tool import KnowledgeSearchTool
from app.rag import KnowledgeBase, build_default_knowledge_base
from app.auth import BaseUserStore, InMemoryUserStore, User, decode_access_token, TokenError
from app.core.config import settings


def _build_memory() -> BaseMemory:
    """
    MEMORY_BACKEND="redis" bo'lsa RedisMemory (persistent), aks holda InMemoryStore.
    Redis ulanib bo'lmasa — ogohlantirib, RAM xotirasiga qaytamiz (ilova yiqilmasin).
    Liskov Substitution: ikkala backend ham bir xil BaseMemory interfeysi.
    """
    if settings.MEMORY_BACKEND.lower() == "redis":
        try:
            return RedisMemory(settings.REDIS_URL)
        except Exception as e:  # pragma: no cover - infra holatiga bog'liq
            import logging
            logging.getLogger("nexus").warning(
                "RedisMemory ishga tushmadi (%s) — InMemoryStore'ga qaytildi", e
            )
    return InMemoryStore()


# ---- Singletonlar (ilova ishga tushganda bir marta quriladi) ----------------
_memory: BaseMemory = _build_memory()

# RAG / Bilim bazasi: standart embedder (Gemini yoki offline Hashing) + vektor ombori.
_knowledge_base: KnowledgeBase = build_default_knowledge_base()

# Auth: ko'p foydalanuvchili JWT — foydalanuvchi ombori singletoni.
_user_store: BaseUserStore = InMemoryUserStore()

# Tool Calling Framework: standart tool to'plami bilan reestr.
# RAG bilim bazasiga bog'liq knowledge_search tool'ini shu yerda qo'shamiz
# (build_default_registry KB'ni bilmaydi — offline test reestrini toza saqlaymiz).
_registry: ToolRegistry = build_default_registry()
_registry.register(KnowledgeSearchTool(_knowledge_base))

# Agentlar
_coder = CoderAgent()
_media = MediaAgent()
_image = ImageAgent()
_planner = PlannerAgent(
    registry=_registry, memory=_memory, knowledge_base=_knowledge_base
)

_router = AgentRouter(coder=_coder, media=_media, planner=_planner, image=_image)


def get_agent_router() -> AgentRouter:
    return _router


def get_memory() -> BaseMemory:
    return _memory


def get_tool_registry() -> ToolRegistry:
    return _registry


def get_planner() -> PlannerAgent:
    return _planner


def get_knowledge_base() -> KnowledgeBase:
    return _knowledge_base


def get_user_store() -> BaseUserStore:
    return _user_store


# ---- Auth guard: Bearer token → joriy foydalanuvchi --------------------------
# fastapi/Depends importlarini shu yerda (modul oxirida) qilamiz — yengil import.
from fastapi import Depends, Header, HTTPException  # noqa: E402


async def get_current_user(
    authorization: str = Header(default=""),
    store: BaseUserStore = Depends(get_user_store),
) -> User:
    """
    `Authorization: Bearer <token>` sarlavhasini tekshiradi, JWT'ni dekodlaydi
    va tegishli foydalanuvchini qaytaradi. Token yo'q/yaroqsiz bo'lsa 401.
    """
    if not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=401,
            detail="Authorization Bearer token talab qilinadi",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = authorization[7:].strip()
    try:
        payload = decode_access_token(token, settings.JWT_SECRET)
    except TokenError as e:
        raise HTTPException(
            status_code=401,
            detail=f"Token yaroqsiz: {e}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = await store.get_by_id(payload.get("sub", ""))
    if user is None:
        raise HTTPException(status_code=401, detail="Foydalanuvchi topilmadi")
    return user
