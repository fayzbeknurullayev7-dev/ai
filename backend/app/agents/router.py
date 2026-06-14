import re
from typing import Any, Dict, List, AsyncIterator
from app.agents.base_agent import BaseAgent, AgentResult
from app.schemas.chat import Message

# Routing keywords
CODE_KEYWORDS = [
    "code", "kod", "function", "class", "bug", "debug", "error", "fix",
    "python", "dart", "flutter", "javascript", "fastapi", "api", "script",
    "algorithm", "implement", "refactor", "compile", "syntax", "loop",
    "array", "database", "sql", "query",
]

MEDIA_KEYWORDS = [
    "rasm", "image", "photo", "rasmni", "video", "audio", "media",
    "design", "dizayn", "color", "rang", "logo", "icon", "ui", "ux",
    "describe", "tasvir", "ko'r", "analiz", "multimodal",
]

# Planner — ko'p qadamli vazifa, hisob-kitob, vaqt yoki xotira talab qilganda.
PLANNER_KEYWORDS = [
    "plan", "reja", "step", "qadam", "vazifa", "task", "hisobla", "calculate",
    "necha", "vaqt", "time", "sana", "date", "esla", "remember", "eslab",
    "avval", "keyin", "then", "first", "research", "tahlil",
]

# Rasm YARATISH (generatsiya) — media tahlilidan farqli, yuqori ustuvorlikda.
_IMAGE_GEN_PHRASES = [
    "rasm yarat", "rasm chiz", "rasm yasa", "rasm tayyorla", "rasmini chiz",
    "surat yarat", "surat chiz", "chizib ber", "rasm generatsiya", "logo yarat",
    "logo chiz", "generate image", "generate an image", "create image",
    "create an image", "draw image", "draw an image", "make image",
    "make an image", "image yarat", "rasm:", "image of",
]
# Generatsiya fe'llari (rasm/image/surat oti bilan birga kelsa).
_GEN_VERBS = {
    "yarat", "yaratib", "chiz", "chizib", "yasa", "yasab", "tayyorla",
    "generate", "create", "draw", "make", "generatsiya",
}
_IMAGE_NOUNS = {"rasm", "rasmni", "rasmini", "surat", "image", "logo", "rasim"}
# Tahlil/ko'rish — bu rasm GENERATSIYASI emas, MediaAgent'ga ketadi.
_ANALYZE_HINTS = {"tahlil", "analiz", "describe", "tasvirla", "tushuntir"}


class AgentRouter:
    """
    Dependency Inversion: Router konkret agentlarga emas,
    BaseAgent interfeysi orqali bog'liq.

    Routing logikasi (eng yuqori ball g'olib, teng bo'lsa quyidagi tartib):
    1. Xabar tokenlarga ajratiladi (so'z chegarasi bo'yicha).
    2. planner / code / media kalitlari sanaladi.
    3. Eng ko'p ball to'plagan agent tanlanadi.
    4. Hech biri topilmasa → CoderAgent (default).
    """

    def __init__(
        self,
        coder: BaseAgent,
        media: BaseAgent,
        planner: BaseAgent,
        image: BaseAgent,
        coder_pro: BaseAgent | None = None,
    ):
        self._coder = coder
        self._media = media
        self._planner = planner
        self._image = image
        # "Kod" tabi uchun elite coder (alohida system prompt). Berilmasa —
        # oddiy coder'ga qaytamiz (orqaga moslik).
        self._coder_pro = coder_pro or coder

    @staticmethod
    def _count_matches(keywords: List[str], tokens: set, lower: str) -> int:
        # So'z chegarasi bo'yicha aniq moslik (substring soxta mosliklardan saqlaydi).
        count = 0
        for kw in keywords:
            if " " in kw or "'" in kw:
                if kw in lower:
                    count += 1
            elif kw in tokens:
                count += 1
        return count

    @staticmethod
    def _is_image_generation(lower: str, tokens: set) -> bool:
        """Rasm GENERATSIYASI (yaratish) so'rovini aniqlaydi — tahlildan farqli.

        1) Aniq ibora ("rasm yarat", "generate image" ...) → True.
        2) Rasm oti (rasm/surat/image/logo) + generatsiya fe'li birga kelsa,
           va tahlil/ko'rish ishorasi bo'lmasa → True.
        """
        # Tahlil/tasvirlash so'rovi bo'lsa — bu generatsiya emas (MediaAgent'ga).
        if tokens & _ANALYZE_HINTS:
            return False
        for phrase in _IMAGE_GEN_PHRASES:
            if phrase in lower:
                return True
        return bool((tokens & _IMAGE_NOUNS) and (tokens & _GEN_VERBS))

    def _select_agent(self, message: str) -> BaseAgent:
        lower = message.lower()
        tokens = set(re.findall(r"[a-zA-Z']+", lower))

        # Rasm yaratish eng yuqori ustuvorlikda — boshqa keyword'lardan oldin.
        if self._is_image_generation(lower, tokens):
            return self._image

        planner_score = self._count_matches(PLANNER_KEYWORDS, tokens, lower)
        media_score = self._count_matches(MEDIA_KEYWORDS, tokens, lower)
        code_score = self._count_matches(CODE_KEYWORDS, tokens, lower)

        best = max(planner_score, media_score, code_score)
        if best == 0:
            return self._coder  # default
        if planner_score == best:
            return self._planner
        if media_score == best:
            return self._media
        return self._coder

    def _agent_for_mode(self, mode: str | None) -> BaseAgent | None:
        """Tabga bog'liq majburiy agent. Noma'lum/None bo'lsa — None (auto)."""
        if not mode:
            return None
        return {
            "image": self._image,
            "code": self._coder_pro,
            "media": self._media,
            "planner": self._planner,
            "chat": self._coder,
        }.get(mode.lower())

    def _resolve(self, message: str, mode: str | None) -> BaseAgent:
        return self._agent_for_mode(mode) or self._select_agent(message)

    async def route(
        self,
        message: str,
        history: List[Message],
        session_id: str = "default",
        mode: str | None = None,
    ) -> AgentResult:
        agent = self._resolve(message, mode)
        return await agent.process(message, history, session_id)

    async def route_stream(
        self,
        message: str,
        history: List[Message],
        session_id: str = "default",
        mode: str | None = None,
    ) -> AsyncIterator[str]:
        agent = self._resolve(message, mode)
        async for chunk in agent.stream(message, history, session_id):
            yield chunk

    async def route_stream_events(
        self,
        message: str,
        history: List[Message],
        session_id: str = "default",
        mode: str | None = None,
    ) -> AsyncIterator[Dict[str, Any]]:
        agent = self._resolve(message, mode)
        async for ev in agent.stream_events(message, history, session_id):
            yield ev
