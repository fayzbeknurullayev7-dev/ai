import ast
import operator
from typing import Any, Dict
from app.tools.base_tool import BaseTool, ExecutionContext, ToolResult

# Ruxsat etilgan operatorlar — `eval` ishlatmasdan xavfsiz hisoblash.
_BIN_OPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.FloorDiv: operator.floordiv,
    ast.Mod: operator.mod,
    ast.Pow: operator.pow,
}
_UNARY_OPS = {
    ast.UAdd: operator.pos,
    ast.USub: operator.neg,
}


def _safe_eval(node: ast.AST) -> float:
    if isinstance(node, ast.Constant):
        if isinstance(node.value, (int, float)):
            return node.value
        raise ValueError("faqat sonlar ruxsat etiladi")
    if isinstance(node, ast.BinOp) and type(node.op) in _BIN_OPS:
        return _BIN_OPS[type(node.op)](_safe_eval(node.left), _safe_eval(node.right))
    if isinstance(node, ast.UnaryOp) and type(node.op) in _UNARY_OPS:
        return _UNARY_OPS[type(node.op)](_safe_eval(node.operand))
    raise ValueError("ruxsat etilmagan ifoda")


class CalculatorTool(BaseTool):
    """Arifmetik ifodalarni xavfsiz hisoblaydi (eval ishlatmaydi)."""

    @property
    def name(self) -> str:
        return "calculator"

    @property
    def description(self) -> str:
        return (
            "Matematik arifmetik ifodani hisoblaydi. "
            "Misol: '2 + 2 * 10', '(5 - 3) ** 4'. "
            "+, -, *, /, //, %, ** operatorlarini qo'llab-quvvatlaydi."
        )

    @property
    def parameters(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "expression": {
                    "type": "string",
                    "description": "Hisoblanadigan arifmetik ifoda",
                }
            },
            "required": ["expression"],
        }

    async def execute(self, args: Dict[str, Any], context: ExecutionContext) -> ToolResult:
        expression = str(args.get("expression", "")).strip()
        if not expression:
            return ToolResult(success=False, output="", error="ifoda bo'sh")
        try:
            tree = ast.parse(expression, mode="eval")
            result = _safe_eval(tree.body)
            return ToolResult(success=True, output=f"{expression} = {result}")
        except Exception as e:
            return ToolResult(success=False, output="", error=f"hisoblab bo'lmadi: {e}")
