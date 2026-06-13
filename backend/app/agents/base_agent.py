from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Dict, List, AsyncIterator
from app.schemas.chat import Message


@dataclass
class AgentResult:
    content: str
    agent_name: str
    model_name: str
    # Planner kabi agentlar ReAct izini (tool chaqiruvlari) shu yerda qaytaradi.
    steps: List[Dict[str, Any]] = field(default_factory=list)


class BaseAgent(ABC):
    """
    SOLID: Single Responsibility — har bir agent faqat o'z vazifasini bajaradi.
    Open/Closed — yangi agentlar BaseAgent'ni extend qilib qo'shiladi.

    `session_id` xotira (Memory System) izolyatsiyasi uchun ixtiyoriy
    uzatiladi; oddiy agentlar uni e'tiborsiz qoldirishi mumkin.
    """

    @property
    @abstractmethod
    def name(self) -> str:
        pass

    @abstractmethod
    async def process(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AgentResult:
        pass

    @abstractmethod
    async def stream(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AsyncIterator[str]:
        pass

    # ---- Tipizatsiyalangan event oqimi (SSE uchun) --------------------------
    async def stream_events(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AsyncIterator[Dict[str, Any]]:
        """
        Standart implementatsiya (Template Method): matnli `stream()` ni
        `token` eventlariga o'raydi. Planner kabi agentlar buni override qilib
        qo'shimcha `step` eventlarini chiqaradi.

        Event turlari: start | token | step | done | error
        """
        yield {"type": "start", "agent": self.name}
        async for chunk in self.stream(message, history, session_id):
            yield {"type": "token", "content": chunk}
        yield {"type": "done"}
