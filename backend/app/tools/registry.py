from typing import Any, Dict, List
from app.tools.base_tool import BaseTool, ExecutionContext, ToolResult


class ToolRegistry:
    """
    Tool'lar reestri — nom bo'yicha ro'yxatga olish, qidirish va bajarish.

    Planner Agent shu reestr orqali LLM ga mavjud tool'lar sxemasini beradi
    va LLM tanlagan tool'ni xavfsiz (xatolarni ushlab) bajaradi.
    """

    def __init__(self) -> None:
        self._tools: Dict[str, BaseTool] = {}

    def register(self, tool: BaseTool) -> "ToolRegistry":
        if tool.name in self._tools:
            raise ValueError(f"'{tool.name}' nomli tool allaqachon ro'yxatda")
        self._tools[tool.name] = tool
        return self  # zanjirli ro'yxatga olish uchun

    def get(self, name: str) -> BaseTool | None:
        return self._tools.get(name)

    def names(self) -> List[str]:
        return list(self._tools.keys())

    def schemas(self) -> List[Dict[str, Any]]:
        """Barcha tool'larning function-calling sxemasi (LLM ga uzatiladi)."""
        return [tool.schema() for tool in self._tools.values()]

    async def execute(
        self, name: str, args: Dict[str, Any], context: ExecutionContext
    ) -> ToolResult:
        tool = self._tools.get(name)
        if tool is None:
            return ToolResult(
                success=False,
                output="",
                error=f"'{name}' nomli tool topilmadi. Mavjud: {self.names()}",
            )
        try:
            return await tool.execute(args, context)
        except Exception as e:  # tool ichidagi har qanday xato observation bo'ladi
            return ToolResult(success=False, output="", error=f"{type(e).__name__}: {e}")
