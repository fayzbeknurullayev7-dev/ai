from typing import List, AsyncIterator
import google.generativeai as genai
from app.agents.base_agent import BaseAgent, AgentResult
from app.core.config import settings
from app.schemas.chat import Message

SYSTEM_PROMPT = """Sen Nexus AI — media va multimodal kontent agenti.
Rasmlar, audio, video haqida savollarga javob ber.
Ijodiy kontent, tasvir tahlili, dizayn maslahatlarida yordam ber.
Uzbek tilida javob ber."""


class MediaAgent(BaseAgent):
    """Gemini (gemini-1.5-flash) orqali media va multimodal vazifalar agenti."""

    def __init__(self):
        genai.configure(api_key=settings.GEMINI_API_KEY)
        self._model_name = "gemini-1.5-flash"
        self._model = genai.GenerativeModel(
            model_name=self._model_name,
            system_instruction=SYSTEM_PROMPT,
        )

    @property
    def name(self) -> str:
        return "MediaAgent"

    def _build_history(self, history: List[Message]) -> list:
        result = []
        for h in history[-10:]:
            role = "user" if h.role == "user" else "model"
            result.append({"role": role, "parts": [h.content]})
        return result

    async def process(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AgentResult:
        chat = self._model.start_chat(history=self._build_history(history))
        response = await chat.send_message_async(message)
        return AgentResult(
            content=response.text,
            agent_name=self.name,
            model_name=self._model_name,
        )

    async def stream(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AsyncIterator[str]:
        chat = self._model.start_chat(history=self._build_history(history))
        response = await chat.send_message_async(message, stream=True)
        async for chunk in response:
            if chunk.text:
                yield chunk.text
