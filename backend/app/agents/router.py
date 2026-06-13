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

    def __init__(self, coder: BaseAgent, media: BaseAgent, planner: BaseAgent):
        self._coder = coder
        self._media = media
        self._planner = planner

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

    def _select_agent(self, message: str) -> BaseAgent:
        lower = message.lower()
        tokens = set(re.findall(r"[a-zA-Z']+", lower))

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

    async def route(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AgentResult:
        agent = self._select_agent(message)
        return await agent.process(message, history, session_id)

    async def route_stream(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AsyncIterator[str]:
        agent = self._select_agent(message)
        async for chunk in agent.stream(message, history, session_id):
            yield chunk

    async def route_stream_events(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AsyncIterator[Dict[str, Any]]:
        agent = self._select_agent(message)
        async for ev in agent.stream_events(message, history, session_id):
            yield ev
