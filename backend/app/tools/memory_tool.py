from typing import Any, Dict
from app.tools.base_tool import BaseTool, ExecutionContext, ToolResult


class MemoryWriteTool(BaseTool):
    """
    LLM ga foydalanuvchi haqidagi muhim faktni uzoq muddatli xotiraga
    yozish imkonini beradi (masalan, ism, til afzalligi, loyiha nomi).
    """

    @property
    def name(self) -> str:
        return "remember_fact"

    @property
    def description(self) -> str:
        return (
            "Foydalanuvchi haqidagi muhim faktni keyingi suhbatlar uchun "
            "xotiraga saqlaydi. Masalan: key='ism', value='Aziz'."
        )

    @property
    def parameters(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "key": {"type": "string", "description": "Fakt kaliti, masalan 'ism'"},
                "value": {"type": "string", "description": "Fakt qiymati"},
            },
            "required": ["key", "value"],
        }

    async def execute(self, args: Dict[str, Any], context: ExecutionContext) -> ToolResult:
        key = str(args.get("key", "")).strip()
        value = str(args.get("value", "")).strip()
        if not key:
            return ToolResult(success=False, output="", error="key bo'sh bo'lishi mumkin emas")
        await context.memory.remember(context.session_id, key, value)
        return ToolResult(success=True, output=f"Eslab qoldim: {key} = {value}")


class MemoryRecallTool(BaseTool):
    """LLM ga xotiradan faktni o'qish imkonini beradi."""

    @property
    def name(self) -> str:
        return "recall_facts"

    @property
    def description(self) -> str:
        return (
            "Xotiradagi saqlangan faktlarni o'qiydi. `key` berilsa bitta "
            "faktni, berilmasa barcha faktlarni qaytaradi."
        )

    @property
    def parameters(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "key": {
                    "type": "string",
                    "description": "Ixtiyoriy. Aniq fakt kaliti.",
                }
            },
            "required": [],
        }

    async def execute(self, args: Dict[str, Any], context: ExecutionContext) -> ToolResult:
        key = args.get("key")
        if key:
            value = await context.memory.recall(context.session_id, str(key))
            if value is None:
                return ToolResult(success=True, output=f"'{key}' bo'yicha fakt yo'q")
            return ToolResult(success=True, output=f"{key} = {value}")

        facts = await context.memory.get_facts(context.session_id)
        if not facts:
            return ToolResult(success=True, output="Xotirada hech qanday fakt yo'q")
        lines = "\n".join(f"- {k}: {v}" for k, v in facts.items())
        return ToolResult(success=True, output=f"Saqlangan faktlar:\n{lines}")
