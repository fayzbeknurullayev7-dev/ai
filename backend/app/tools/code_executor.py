import asyncio
import sys
from typing import Any, Dict
from app.tools.base_tool import BaseTool, ExecutionContext, ToolResult

# POSIX'da resurs cheklovlari (CPU vaqti, xotira). Windows'da mavjud emas.
try:
    import resource  # noqa: E402
except ImportError:  # pragma: no cover - Windows
    resource = None


def _apply_limits(cpu_seconds: int, mem_bytes: int):
    """Subprocess ichida resurs cheklovlarini o'rnatadi (preexec_fn)."""
    def _limit():
        if resource is None:
            return
        resource.setrlimit(resource.RLIMIT_CPU, (cpu_seconds, cpu_seconds))
        resource.setrlimit(resource.RLIMIT_AS, (mem_bytes, mem_bytes))
        # Yangi fayl yozishni cheklash (0 bayt) — disk to'ldirishni oldini oladi.
        try:
            resource.setrlimit(resource.RLIMIT_FSIZE, (0, 0))
        except (ValueError, OSError):
            pass
    return _limit


class CodeExecutorTool(BaseTool):
    """
    Python kodini IZOLYATSIYALANGAN subprocess'da bajaradi.

    Himoya choralari:
      • Alohida `python3 -I` jarayoni (izolyatsiya rejimi: PYTHON* o'zgaruvchilar
        va user-site e'tiborsiz).
      • `wall-clock` timeout (asyncio) + CPU vaqti limiti (RLIMIT_CPU).
      • Xotira limiti (RLIMIT_AS) va fayl yozish taqiqi (RLIMIT_FSIZE=0).
      • stdout/stderr cheklangan uzunlikda qaytariladi.

    ⚠️ DIQQAT: bu yengil sandbox, to'liq xavfsizlik chegarasi EMAS. Ishonchsiz
    kodni ishlatish uchun production'da konteyner (Docker/gVisor) yoki
    maxsus sandbox (nsjail/firejail) ishlating.
    """

    def __init__(
        self,
        timeout_seconds: float = 5.0,
        cpu_seconds: int = 5,
        mem_mb: int = 256,
        max_output: int = 4000,
    ) -> None:
        self._timeout = timeout_seconds
        self._cpu = cpu_seconds
        self._mem = mem_mb * 1024 * 1024
        self._max_output = max_output

    @property
    def name(self) -> str:
        return "execute_python"

    @property
    def description(self) -> str:
        return (
            "Python kodini bajaradi va stdout natijasini qaytaradi. Hisob-kitob, "
            "ma'lumotni qayta ishlash yoki algoritmni tekshirish uchun. "
            "Natijani ko'rish uchun print() ishlating. Tarmoq/fayl yozish cheklangan."
        )

    @property
    def parameters(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "code": {"type": "string", "description": "Bajariladigan Python kodi"}
            },
            "required": ["code"],
        }

    def _truncate(self, text: str) -> str:
        if len(text) > self._max_output:
            return text[: self._max_output] + "\n... (natija qisqartirildi)"
        return text

    async def execute(self, args: Dict[str, Any], context: ExecutionContext) -> ToolResult:
        code = str(args.get("code", ""))
        if not code.strip():
            return ToolResult(success=False, output="", error="kod bo'sh")

        preexec = _apply_limits(self._cpu, self._mem) if resource is not None else None

        try:
            proc = await asyncio.create_subprocess_exec(
                sys.executable, "-I", "-c", code,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                preexec_fn=preexec,  # POSIX only; None bo'lsa e'tiborsiz
            )
        except Exception as e:
            return ToolResult(success=False, output="", error=f"jarayon yaratilmadi: {e}")

        try:
            stdout_b, stderr_b = await asyncio.wait_for(
                proc.communicate(), timeout=self._timeout
            )
        except asyncio.TimeoutError:
            proc.kill()
            await proc.wait()
            return ToolResult(
                success=False,
                output="",
                error=f"timeout: kod {self._timeout}s ichida tugamadi",
            )

        stdout = self._truncate(stdout_b.decode(errors="replace").strip())
        stderr = self._truncate(stderr_b.decode(errors="replace").strip())

        if proc.returncode != 0:
            return ToolResult(
                success=False,
                output=stdout,
                error=stderr or f"jarayon {proc.returncode} kod bilan tugadi",
            )

        return ToolResult(
            success=True,
            output=stdout if stdout else "(stdout bo'sh — print() ishlatdingizmi?)",
        )
