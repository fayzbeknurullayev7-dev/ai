"""
KnowledgeSearchTool — Planner Agent'ga loyiha bilim bazasidan (RAG) semantik
qidirish imkonini beradi.

Tool web_search'dan farqi: bu internetga emas, oldindan yuklangan ICHKI
hujjatlarga (bilim bazasi) qaraydi. Agent foydalanuvchiga xos / loyihaga xos
ma'lumot kerak bo'lganda shu tool'ni chaqiradi.
"""
from typing import Any, Dict

from app.tools.base_tool import BaseTool, ExecutionContext, ToolResult
from app.rag.knowledge_base import KnowledgeBase


class KnowledgeSearchTool(BaseTool):
    """Bilim bazasidan eng mos bo'laklarni qaytaradi (Retrieval)."""

    def __init__(self, knowledge_base: KnowledgeBase, top_k: int = 4) -> None:
        self._kb = knowledge_base
        self._top_k = top_k

    @property
    def name(self) -> str:
        return "knowledge_search"

    @property
    def description(self) -> str:
        return (
            "Loyiha bilim bazasidan (yuklangan hujjatlar, qo'llanmalar, ichki "
            "ma'lumotlar) semantik qidiradi. Foydalanuvchi yoki loyihaga xos, "
            "internetdan topib bo'lmaydigan ma'lumot kerak bo'lganda ishlating."
        )

    @property
    def parameters(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Bilim bazasidan qidiriladigan savol yoki mavzu",
                },
                "top_k": {
                    "type": "integer",
                    "description": f"Qaytariladigan bo'laklar soni (standart {self._top_k})",
                },
            },
            "required": ["query"],
        }

    async def execute(self, args: Dict[str, Any], context: ExecutionContext) -> ToolResult:
        query = str(args.get("query", "")).strip()
        if not query:
            return ToolResult(success=False, output="", error="qidiruv so'rovi bo'sh")

        # LLM top_k'ni ba'zan matn ("4") yoki float (4.0) sifatida yuboradi —
        # uni har doim butun songa (integer) keltiramiz, aks holda kb.query /
        # vektor ombori slicing'ida xato bo'ladi.
        raw_top_k = args.get("top_k")
        if raw_top_k is None or raw_top_k == "":
            top_k = self._top_k
        else:
            try:
                top_k = max(1, int(float(raw_top_k)))
            except (TypeError, ValueError):
                top_k = self._top_k

        # session_id = user.id → tool faqat shu foydalanuvchining bilim bazasidan qidiradi.
        owner = context.session_id or None
        try:
            chunks = await self._kb.query(query, top_k=top_k, owner=owner)
        except Exception as e:
            return ToolResult(
                success=False, output="",
                error=f"bilim bazasi qidiruv xatosi: {type(e).__name__}: {e}",
            )

        if not chunks:
            return ToolResult(
                success=True,
                output=f"'{query}' bo'yicha bilim bazasida mos ma'lumot topilmadi.",
            )

        lines = [f"Bilim bazasi natijalari '{query}':"]
        for i, ch in enumerate(chunks, 1):
            src = ch.title or ch.document_id
            lines.append(f"[{i}] ({src}, o'xshashlik={ch.score}) {ch.text}")
        return ToolResult(success=True, output="\n".join(lines))
