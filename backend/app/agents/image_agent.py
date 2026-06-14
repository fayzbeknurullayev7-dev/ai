from typing import Any, AsyncIterator, Dict, List
from urllib.parse import quote
from app.agents.base_agent import BaseAgent, AgentResult
from app.schemas.chat import Message

# Pollinations.ai — bepul rasm yaratish xizmati (API key shart emas).
# Promptni to'g'ridan URL ichiga qo'yib so'rov yuboriladi, natija — rasm URL'i.
# Hujjat: https://image.pollinations.ai/prompt/{prompt}
_POLLINATIONS_BASE = "https://image.pollinations.ai/prompt"
_IMAGE_MODEL = "pollinations"


class ImageAgent(BaseAgent):
    """Pollinations.ai orqali matnli promptdan rasm yaratuvchi agent.

    Foydalanuvchi "rasm yarat / rasm chiz / image" desa, router shu agentga
    yo'naltiradi. Natija SSE oqimida `image` (image_url) eventi sifatida keladi.

    Gemini imagen API o'rniga bepul Pollinations.ai ishlatiladi — API key
    talab qilinmaydi, prompt URL'ga joylanib, tayyor rasm URL'i qaytariladi.
    """

    def __init__(self):
        self._model = _IMAGE_MODEL

    @property
    def name(self) -> str:
        return "ImageAgent"

    @staticmethod
    def _clean_prompt(message: str) -> str:
        """Trigger so'zlarni ('rasm yarat' va h.k.) olib, sof tavsifni qoldiradi."""
        cleaned = message.strip()
        lowered = cleaned.lower()
        for trigger in (
            "rasm yaratib ber", "rasm chizib ber", "rasm yasab ber",
            "rasm yarat", "rasm chiz", "rasm yasa", "rasm tayyorla",
            "surat yarat", "surat chiz", "rasmini chiz", "chizib ber",
            "generate an image of", "generate image of", "generate image",
            "create an image of", "create image of", "create image",
            "draw an image of", "draw image", "draw me", "make an image of",
            "make image", "image of", "rasm:", "image:",
        ):
            if lowered.startswith(trigger):
                cleaned = cleaned[len(trigger):].strip(" :,-")
                break
        return cleaned or message.strip()

    def _build_image_url(self, prompt: str) -> str:
        """Promptni URL-encode qilib, Pollinations.ai rasm URL'ini quradi."""
        # safe="" — bo'shliq va maxsus belgilar ham to'liq enkodlanadi.
        encoded = quote(prompt, safe="")
        return f"{_POLLINATIONS_BASE}/{encoded}"

    async def process(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AgentResult:
        prompt = self._clean_prompt(message)
        caption = f'"{prompt}" uchun rasm tayyor.'
        return AgentResult(
            content=caption,
            agent_name=self.name,
            model_name=self._model,
        )

    async def stream(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AsyncIterator[str]:
        # Oddiy matnli oqim ishlatilmaydi — stream_events override qilingan.
        result = await self.process(message, history, session_id)
        yield result.content

    async def stream_events(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AsyncIterator[Dict[str, Any]]:
        """start → (token izoh) → image(image_url) → done.

        Pollinations.ai sinxron API key talab qilmaydi, shuning uchun rasm URL'i
        darhol quriladi — tarmoq so'rovi Flutter `Image.network()` tomonida
        amalga oshadi (yuklash holati shu yerda ko'rsatiladi).
        """
        yield {"type": "start", "agent": self.name, "model": self._model}
        prompt = self._clean_prompt(message)
        image_url = self._build_image_url(prompt)
        caption = f'"{prompt}" uchun rasm tayyor.'
        yield {"type": "token", "content": caption}
        yield {
            "type": "image",
            "image_url": image_url,
            "caption": caption,
        }
        yield {"type": "done"}
