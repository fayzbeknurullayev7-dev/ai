from typing import List, AsyncIterator
from groq import AsyncGroq
from app.agents.base_agent import BaseAgent, AgentResult
from app.core.config import settings
from app.schemas.chat import Message

SYSTEM_PROMPT = """Sen Nexus AI — professional kod yozuvchi agent.
Foydalanuvchi so'ragan har qanday dasturlash vazifasini hal qil.
Kodlarni markdown code block ichida yoz.
Qisqa va aniq izoh ber. Uzbek tilida javob ber, kod ingliz tilida bo'lsin."""

# "Kod" tabi uchun — dunyo darajasidagi senior dasturchi xulqi.
ELITE_CODER_PROMPT = """Sen Nexus AI Coder Pro — dunyodagi eng kuchli senior dasturchisan.
Asosiy prinsiplaring:
- To'liq, ishlaydigan, production-ready kod yoz (yarim yechim emas).
- Toza kod, SOLID, to'g'ri nomlash, edge-case'lar va xatolarni hisobga olish.
- Har doim kodni tilga mos markdown code block ichida ber (```python, ```dart, ...).
- Avval qisqa reja/yondashuv, so'ng kod, so'ng kerak bo'lsa qisqa izoh va misol.
- Murakkablik (Big-O), xavfsizlik va performansga e'tibor ber.
- Noaniq joy bo'lsa eng maqbul taxminni aytib davom et — to'xtab qolma.
Uzbek tilida tushuntir, kod va identifikatorlar ingliz tilida bo'lsin.
Ortiqcha suvga yo'l qo'yma: aniq, ishonchli, amaliy javob ber."""


class CoderAgent(BaseAgent):
    """Groq (llama-3.3-70b) orqali kod yozish va debug qilish agenti.

    `system_prompt` va `agent_name` orqali sozlanadi — masalan "Kod" tabi
    uchun elite (Coder Pro) variant alohida promptli nusxa sifatida quriladi.
    """

    def __init__(
        self,
        system_prompt: str = SYSTEM_PROMPT,
        agent_name: str = "CoderAgent",
        temperature: float = 0.3,
    ):
        self._client = AsyncGroq(api_key=settings.GROQ_API_KEY)
        # FIX (#4): "llama3-70b-8192" Groq tomonidan decommission qilingan.
        # Hozirgi ishlaydigan model — llama-3.3-70b-versatile.
        self._model = "llama-3.3-70b-versatile"
        self._system_prompt = system_prompt
        self._name = agent_name
        self._temperature = temperature

    @property
    def name(self) -> str:
        return self._name

    def _build_messages(self, message: str, history: List[Message]) -> list:
        msgs = [{"role": "system", "content": self._system_prompt}]
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
            temperature=self._temperature,
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
            temperature=self._temperature,
            stream=True,
        )
        async for chunk in stream:
            delta = chunk.choices[0].delta.content
            if delta:
                yield delta
