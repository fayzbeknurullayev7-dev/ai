from datetime import datetime, timezone
from typing import Any, Dict
from app.tools.base_tool import BaseTool, ExecutionContext, ToolResult


class DateTimeTool(BaseTool):
    """Joriy sana va vaqtni (UTC) qaytaradi."""

    @property
    def name(self) -> str:
        return "current_datetime"

    @property
    def description(self) -> str:
        return "Hozirgi sana va vaqtni ISO-8601 formatida (UTC) qaytaradi."

    @property
    def parameters(self) -> Dict[str, Any]:
        return {"type": "object", "properties": {}, "required": []}

    async def execute(self, args: Dict[str, Any], context: ExecutionContext) -> ToolResult:
        now = datetime.now(timezone.utc).isoformat()
        return ToolResult(success=True, output=f"Hozirgi vaqt (UTC): {now}")
