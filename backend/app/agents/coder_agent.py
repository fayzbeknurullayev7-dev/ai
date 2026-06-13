from typing import List, AsyncIterator
from groq import AsyncGroq
from app.agents.base_agent import BaseAgent, AgentResult
from app.core.config import settings
from app.schemas.chat import Message

SYSTEM_PROMPT = """Sen Nexus AI — professional kod yozuvchi agent.
Foydalanuvchi so'ragan har qanday dasturlash vazifasini hal qil.
Kodlarni markdown code block ichida yoz.
Qisqa va aniq izoh ber. Uzbek tilida javob ber, kod ingliz tilida bo'lsin."""


class CoderAgent(BaseAgent):
    """Groq (llama-3.3-70b) orqali kod yozish va debug qilish agenti."""

    def __init__(self):
        self._client = AsyncGroq(api_key=settings.GROQ_API_KEY)
        # FIX (#4): "llama3-70b-8192" Groq tomonidan decommission qilingan.
        # Hozirgi ishlaydigan model — llama-3.3-70b-versatile.
        self._model = "llama-3.3-70b-versatile"

    @property
    def name(self) -> str:
        return "CoderAgent"

    def _build_messages(self, message: str, history: List[Message]) -> list:
        msgs = [{"role": "system", "content": SYSTEM_PROMPT}]
        for h in history[-10:]:  # last 10 turns
            msgs.append({"role": h.role, "content": h.content})
        msgs.append({"role": "user", "content": message})
        return msgs

    async def process(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AgentResult:
        response = await self._client.chat.completions.create(
            model=self._model,
            messages=self._build_messages(message, history),
            max_tokens=4096,
            temperature=0.3,
        )
        content = response.choices[0].message.content
        return AgentResult(content=content, agent_name=self.name, model_name=self._model)

    async def stream(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AsyncIterator[str]:
        stream = await self._client.chat.completions.create(
            model=self._model,
            messages=self._build_messages(message, history),
            max_tokens=4096,
            temperature=0.3,
            stream=True,
        )
        async for chunk in stream:
            delta = chunk.choices[0].delta.content
            if delta:
                yield delta
