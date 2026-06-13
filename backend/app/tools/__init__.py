from app.tools.base_tool import BaseTool, ExecutionContext, ToolResult
from app.tools.registry import ToolRegistry
from app.tools.calculator import CalculatorTool
from app.tools.datetime_tool import DateTimeTool
from app.tools.memory_tool import MemoryWriteTool, MemoryRecallTool
from app.tools.web_search import WebSearchTool
from app.tools.code_executor import CodeExecutorTool

__all__ = [
    "BaseTool",
    "ExecutionContext",
    "ToolResult",
    "ToolRegistry",
    "build_default_registry",
]


def build_default_registry() -> ToolRegistry:
    """Standart tool to'plami bilan reestr yaratadi."""
    registry = ToolRegistry()
    (
        registry.register(CalculatorTool())
        .register(DateTimeTool())
        .register(MemoryWriteTool())
        .register(MemoryRecallTool())
        .register(WebSearchTool())
        .register(CodeExecutorTool())
    )
    return registry
