"""
Pytest integratsiya testlari uchun umumiy fixturalar.

Real Groq/Gemini API'siz ishlaydi: FastAPI dependency override orqali
soxta (fake) agentlar va injeksiya qilingan FakeClient bilan real
PlannerAgent ishlatiladi. Har bir test toza InMemoryStore va ToolRegistry
oladi (sessiyalar orasida holat oqib ketmaydi).
"""
import json
from types import SimpleNamespace
from typing import AsyncIterator, Dict, List

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from main import app
from app.agents.base_agent import BaseAgent, AgentResult
from app.agents.router import AgentRouter
from app.agents.planner_agent import PlannerAgent
from app.core import dependencies as deps
from app.memory import InMemoryStore
from app.schemas.chat import Message
from app.tools import build_default_registry
from app.tools.knowledge_tool import KnowledgeSearchTool
from app.rag import HashingEmbedder, InMemoryVectorStore, KnowledgeBase
from app.auth import InMemoryUserStore


# --------------------------------------------------------------------------- #
# Soxta Groq klienti (Planner ReAct sikli uchun)                              #
# --------------------------------------------------------------------------- #
def _tool_call(call_id: str, name: str, arguments: dict):
    return SimpleNamespace(
        id=call_id,
        function=SimpleNamespace(name=name, arguments=json.dumps(arguments)),
    )


def _response(content=None, tool_calls=None):
    msg = SimpleNamespace(content=content, tool_calls=tool_calls)
    return SimpleNamespace(choices=[SimpleNamespace(message=msg)])


class FakeCompletions:
    """1-chaqiruvda calculator tool, 2-chaqiruvda yakuniy javob qaytaradi."""

    def __init__(self):
        self.calls = 0
        self.last_messages = None  # injection tekshiruvi uchun oxirgi yuborilgan xabarlar

    async def create(self, **kwargs):
        self.calls += 1
        self.last_messages = kwargs.get("messages")
        if self.calls == 1:
            return _response(
                tool_calls=[
                    _tool_call("c1", "calculator", {"expression": "12 * (3 + 4)"})
                ]
            )
        return _response(content="Hisob natijasi: 84.")


class FakeClient:
    """AsyncGroq o'rnini bosuvchi minimal klient."""

    def __init__(self):
        self.chat = SimpleNamespace(completions=FakeCompletions())


class FakeNoToolClient:
    """Tool chaqirmasdan to'g'ridan-to'g'ri javob beradigan klient."""

    def __init__(self):
        async def create(**kwargs):
            return _response(content="To'g'ridan-to'g'ri javob.")

        self.chat = SimpleNamespace(completions=SimpleNamespace(create=create))


# --------------------------------------------------------------------------- #
# Soxta oddiy agentlar (CoderAgent / MediaAgent o'rniga — API'siz)            #
# --------------------------------------------------------------------------- #
class FakeAgent(BaseAgent):
    """Belgilangan nom va model bilan deterministik javob beradigan agent."""

    def __init__(self, agent_name: str, model_name: str):
        self._name = agent_name
        self._model = model_name

    @property
    def name(self) -> str:
        return self._name

    async def process(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AgentResult:
        return AgentResult(
            content=f"[{self._name}] javob: {message}",
            agent_name=self._name,
            model_name=self._model,
        )

    async def stream(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AsyncIterator[str]:
        for word in f"[{self._name}] {message}".split():
            yield word + " "


# --------------------------------------------------------------------------- #
# Fixturalar                                                                  #
# --------------------------------------------------------------------------- #
@pytest.fixture
def memory():
    """Har bir test uchun toza xotira."""
    return InMemoryStore()


@pytest.fixture
def knowledge_base():
    """Har bir test uchun toza, OFFLINE bilim bazasi (HashingEmbedder)."""
    return KnowledgeBase(
        embedder=HashingEmbedder(), store=InMemoryVectorStore()
    )


@pytest.fixture
def registry(knowledge_base):
    """Standart tool to'plami + RAG knowledge_search tool'i (toza reestr)."""
    reg = build_default_registry()
    reg.register(KnowledgeSearchTool(knowledge_base))
    return reg


@pytest.fixture
def fake_coder():
    return FakeAgent("CoderAgent", "llama-3.3-70b-versatile")


@pytest.fixture
def fake_media():
    return FakeAgent("MediaAgent", "gemini-1.5-flash")


@pytest.fixture
def fake_image():
    return FakeAgent("ImageAgent", "gemini-2.0-flash-preview-image-generation")


@pytest.fixture
def planner(registry, memory, knowledge_base):
    """Injeksiya qilingan FakeClient + RAG bilim bazasi bilan REAL PlannerAgent."""
    return PlannerAgent(
        registry=registry,
        memory=memory,
        client=FakeClient(),
        knowledge_base=knowledge_base,
    )


@pytest.fixture
def agent_router(fake_coder, fake_media, planner, fake_image):
    return AgentRouter(
        coder=fake_coder, media=fake_media, planner=planner, image=fake_image
    )


@pytest.fixture
def user_store():
    """Har bir test uchun toza foydalanuvchi ombori."""
    return InMemoryUserStore()


@pytest_asyncio.fixture
async def client(agent_router, planner, memory, registry, knowledge_base, user_store):
    """
    FastAPI ilovasini soxta bog'liqliklar bilan override qilib,
    ASGI transport orqali HTTP integratsiya klientini beradi.

    Eslatma: bu klient AUTENTIFIKATSIYASIZ — auth testlari (401/422) shu orqali
    ishlaydi. Himoyalangan endpointlar (chat/agent/rag) uchun `auth_client` ishlating.
    """
    app.dependency_overrides[deps.get_agent_router] = lambda: agent_router
    app.dependency_overrides[deps.get_planner] = lambda: planner
    app.dependency_overrides[deps.get_memory] = lambda: memory
    app.dependency_overrides[deps.get_tool_registry] = lambda: registry
    app.dependency_overrides[deps.get_knowledge_base] = lambda: knowledge_base
    app.dependency_overrides[deps.get_user_store] = lambda: user_store

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


async def register_user(
    ac: AsyncClient,
    email: str = "user@example.com",
    password: str = "secret123",
    full_name: str = "Test User",
):
    """Foydalanuvchi ro'yxatdan o'tkazadi va (user_dict, token) qaytaradi."""
    resp = await ac.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "full_name": full_name},
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    return body["user"], body["token"]["access_token"]


def auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def auth_client(client):
    """
    Ro'yxatdan o'tgan foydalanuvchi tokeni standart sarlavhaga o'rnatilgan klient.

    Himoyalangan endpointlar (chat/agent/rag) shu klient orqali avtomatik
    autentifikatsiya qilinadi — har test bitta foydalanuvchi kontekstida ishlaydi.
    `user` atributi orqali joriy foydalanuvchi ma'lumoti olinadi.
    """
    user, token = await register_user(client, email="primary@example.com")
    client.headers.update(auth_header(token))
    client.user = user  # type: ignore[attr-defined]
    yield client

