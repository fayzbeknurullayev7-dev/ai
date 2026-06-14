from typing import Any, AsyncIterator, Dict, List
import httpx
from app.agents.base_agent import BaseAgent, AgentResult
from app.core.config import settings
from app.schemas.chat import Message

# Gemini rasm yaratish modeli (AI Studio / Generative Language API).
# Matn + rasmni bitta javobda qaytaradi (responseModalities: TEXT, IMAGE).
# Avval eng kuchli model sinaladi; ishlamasa (model topilmasa/xato) — fallback.
_PRIMARY_IMAGE_MODEL = "gemini-3-pro-image"
_FALLBACK_IMAGE_MODEL = "gemini-2.0-flash-preview-image-generation"
_API_BASE = "https://generativelanguage.googleapis.com/v1beta/models"


class ImageAgent(BaseAgent):
    """Gemini orqali matnli promptdan rasm yaratuvchi agent.

    Foydalanuvchi "rasm yarat / rasm chiz / image" desa, router shu agentga
    yo'naltiradi. Natija SSE oqimida `image` (base64) eventi sifatida keladi.

    Model tanlash: avval `gemini-3-pro-image`, u ishlamasa avtomatik ravishda
    `gemini-2.0-flash-preview-image-generation` ga qaytadi (runtime fallback).
    """

    def __init__(self):
        self._api_key = settings.GEMINI_API_KEY
        # Sinab ko'rish tartibi: birinchisi muvaffaqiyatsiz bo'lsa keyingisi.
        self._models = [_PRIMARY_IMAGE_MODEL, _FALLBACK_IMAGE_MODEL]
        self._model = _PRIMARY_IMAGE_MODEL

    @property
    def name(self) -> str:
        return "ImageAgent"

    def _url(self, model: str) -> str:
        return f"{_API_BASE}/{model}:generateContent?key={self._api_key}"

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

    async def _generate(self, prompt: str) -> Dict[str, Any]:
        """Gemini API'ga so'rov yuborib, {text, image_b64, mime, model} qaytaradi.

        Modellarni navbat bilan sinaydi: birinchisi xato bersa (model topilmadi,
        4xx/5xx yoki rasm qaytarmasa) — keyingisiga o'tadi. Hammasi muvaffaqiyatsiz
        bo'lsa oxirgi xatoni ko'taradi.
        """
        if not self._api_key:
            raise RuntimeError("GEMINI_API_KEY o'rnatilmagan")

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]},
        }
        last_error: Exception | None = None
        async with httpx.AsyncClient(timeout=90.0) as client:
            for model in self._models:
                try:
                    resp = await client.post(self._url(model), json=payload)
                    if resp.status_code != 200:
                        raise RuntimeError(
                            f"Gemini image API ({model}) {resp.status_code}: "
                            f"{resp.text[:300]}"
                        )
                    parsed = self._parse_response(resp.json())
                    parsed["model"] = model
                    return parsed
                except Exception as e:  # bu modelda ishlamadi — keyingisiga o'tamiz
                    last_error = e
                    continue

        raise last_error or RuntimeError("Rasm yaratib bo'lmadi (noma'lum xato).")

    @staticmethod
    def _parse_response(data: Dict[str, Any]) -> Dict[str, Any]:
        """Gemini javobidan {text, image_b64, mime} ajratadi (rasm bo'lmasa xato)."""
        text_out, image_b64, mime = "", None, "image/png"
        candidates = data.get("candidates") or []
        if candidates:
            parts = (candidates[0].get("content") or {}).get("parts") or []
            for part in parts:
                if "text" in part and part["text"]:
                    text_out += part["text"]
                inline = part.get("inlineData") or part.get("inline_data")
                if inline and inline.get("data"):
                    image_b64 = inline["data"]
                    mime = inline.get("mimeType") or inline.get("mime_type") or mime

        if image_b64 is None:
            raise RuntimeError("Gemini rasm qaytarmadi (faqat matn keldi).")
        return {"text": text_out.strip(), "image_b64": image_b64, "mime": mime}

    async def process(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AgentResult:
        prompt = self._clean_prompt(message)
        result = await self._generate(prompt)
        caption = result["text"] or f'"{prompt}" uchun rasm tayyor.'
        return AgentResult(
            content=caption,
            agent_name=self.name,
            model_name=result.get("model", self._model),
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
        """start → (token izoh) → image(base64) → done.

        Xato bo'lsa `error` eventi yuboriladi (sse_response uni ham uzatadi).
        """
        yield {"type": "start", "agent": self.name, "model": self._model}
        prompt = self._clean_prompt(message)
        try:
            result = await self._generate(prompt)
        except Exception as e:  # foydalanuvchiga tushunarli xato
            yield {
                "type": "error",
                "detail": f"Rasm yaratib bo'lmadi: {e}",
            }
            return

        caption = result["text"] or f'"{prompt}" uchun rasm tayyor.'
        yield {"type": "token", "content": caption}
        yield {
            "type": "image",
            "data": result["image_b64"],
            "mimeType": result["mime"],
            "caption": caption,
        }
        yield {"type": "done"}
