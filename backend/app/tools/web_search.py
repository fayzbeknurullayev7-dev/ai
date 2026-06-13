from typing import Any, Dict, Optional
from app.tools.base_tool import BaseTool, ExecutionContext, ToolResult
from app.core.config import settings


class WebSearchTool(BaseTool):
    """
    Haqiqiy web qidiruv tool'i.

    Standart: DuckDuckGo Instant Answer API — kalit (API key) talab qilmaydi.
    Agar `settings.TAVILY_API_KEY` o'rnatilgan bo'lsa — Tavily ishlatiladi
    (boyroq, ranjlangan natijalar).

    HTTP klienti konstruktorda injeksiya qilinishi mumkin (offline test uchun).
    httpx faqat ishlash vaqtida import qilinadi — modul importi yengil qoladi.
    """

    def __init__(self, client: Optional[Any] = None, timeout: float = 10.0,
                 max_results: int = 5) -> None:
        self._client = client
        self._timeout = timeout
        self._max_results = max_results

    @property
    def name(self) -> str:
        return "web_search"

    @property
    def description(self) -> str:
        return (
            "Internetdan dolzarb ma'lumot qidiradi. Yangiliklar, faktlar, "
            "ta'riflar yoki model bilmaydigan narsalar uchun ishlating."
        )

    @property
    def parameters(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Qidiruv so'rovi"}
            },
            "required": ["query"],
        }

    async def execute(self, args: Dict[str, Any], context: ExecutionContext) -> ToolResult:
        query = str(args.get("query", "")).strip()
        if not query:
            return ToolResult(success=False, output="", error="qidiruv so'rovi bo'sh")

        client = self._client
        owns_client = False
        if client is None:
            import httpx  # lazy import
            client = httpx.AsyncClient(timeout=self._timeout)
            owns_client = True

        try:
            if settings.TAVILY_API_KEY:
                output = await self._search_tavily(client, query)
            else:
                output = await self._search_duckduckgo(client, query)
            return ToolResult(success=True, output=output)
        except Exception as e:
            return ToolResult(
                success=False, output="", error=f"qidiruv xatosi: {type(e).__name__}: {e}"
            )
        finally:
            if owns_client:
                await client.aclose()

    # --- providerlar ------------------------------------------------------
    async def _search_duckduckgo(self, client: Any, query: str) -> str:
        resp = await client.get(
            "https://api.duckduckgo.com/",
            params={"q": query, "format": "json", "no_html": 1, "skip_disambig": 1},
        )
        resp.raise_for_status()
        data = resp.json()

        parts = []
        heading = data.get("Heading")
        abstract = data.get("AbstractText") or data.get("Abstract")
        if abstract:
            prefix = f"{heading}: " if heading else ""
            parts.append(f"{prefix}{abstract}")
        if data.get("Answer"):
            parts.append(f"Javob: {data['Answer']}")

        for topic in (data.get("RelatedTopics") or []):
            if len(parts) >= self._max_results:
                break
            text = topic.get("Text") if isinstance(topic, dict) else None
            if text:
                url = topic.get("FirstURL", "")
                parts.append(f"- {text}" + (f" ({url})" if url else ""))

        if not parts:
            return f"'{query}' bo'yicha aniq natija topilmadi."
        return f"Qidiruv natijalari '{query}':\n" + "\n".join(parts)

    async def _search_tavily(self, client: Any, query: str) -> str:
        resp = await client.post(
            "https://api.tavily.com/search",
            json={
                "api_key": settings.TAVILY_API_KEY,
                "query": query,
                "max_results": self._max_results,
                "search_depth": "basic",
            },
        )
        resp.raise_for_status()
        data = resp.json()

        parts = []
        if data.get("answer"):
            parts.append(f"Javob: {data['answer']}")
        for item in (data.get("results") or [])[: self._max_results]:
            title = item.get("title", "")
            content = (item.get("content", "") or "")[:200]
            url = item.get("url", "")
            parts.append(f"- {title}: {content} ({url})")

        if not parts:
            return f"'{query}' bo'yicha natija topilmadi."
        return f"Qidiruv natijalari '{query}':\n" + "\n".join(parts)
