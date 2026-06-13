from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Dict
from app.memory.base_memory import BaseMemory


@dataclass
class ToolResult:
    """Tool bajarilishi natijasi — LLM ga observation sifatida qaytadi."""

    success: bool
    output: str
    error: str | None = None

    def as_observation(self) -> str:
        """LLM `tool` xabariga joylanadigan matn."""
        if self.success:
            return self.output
        return f"ERROR: {self.error or 'nomalum xato'}"


@dataclass
class ExecutionContext:
    """
    Tool'ga ishlash vaqtida (runtime) beriladigan kontekst.

    Bu LLM tomonidan to'ldirilmaydi — server tomonidan injeksiya qilinadi.
    Shu sabab session_id kabi maydonlar tool parametrlarida emas, shu yerda.
    """

    session_id: str
    memory: BaseMemory
    extra: Dict[str, Any] = field(default_factory=dict)


class BaseTool(ABC):
    """
    Tool Calling Framework asosi (SOLID).

    Har bir tool:
      • `name`        — LLM chaqiradigan funksiya nomi (unique).
      • `description` — LLM qachon ishlatishni tushunishi uchun izoh.
      • `parameters`  — JSON Schema (object) ko'rinishidagi argumentlar.
      • `execute()`   — argument va kontekst bilan asinxron bajariladi.

    Yangi tool qo'shish = BaseTool'ni extend qilish (Open/Closed).
    """

    @property
    @abstractmethod
    def name(self) -> str:
        ...

    @property
    @abstractmethod
    def description(self) -> str:
        ...

    @property
    @abstractmethod
    def parameters(self) -> Dict[str, Any]:
        """JSON Schema: {"type": "object", "properties": {...}, "required": [...]}"""
        ...

    @abstractmethod
    async def execute(self, args: Dict[str, Any], context: ExecutionContext) -> ToolResult:
        ...

    def schema(self) -> Dict[str, Any]:
        """Groq/OpenAI function-calling formatidagi spetsifikatsiya."""
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.parameters,
            },
        }
