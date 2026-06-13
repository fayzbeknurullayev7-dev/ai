"""
Offline test — tarmoqsiz (Groq/Gemini kalitisiz) Planner Agent, Tool Registry
va Memory System ishlashini tekshiradi.

Soxta (fake) LLM klienti injeksiya qilinadi: u avval `calculator` tool'ini
chaqiradi, observation'ni olgach yakuniy javob qaytaradi. Bu ReAct siklining
to'liq aylanishini real API'siz sinaydi.

Ishga tushirish:  cd backend && python tests/test_offline.py
"""
import asyncio
import json
from types import SimpleNamespace

from app.tools import build_default_registry, ExecutionContext
from app.tools.web_search import WebSearchTool
from app.tools.code_executor import CodeExecutorTool
from app.memory import InMemoryStore
from app.agents.planner_agent import PlannerAgent
from app.schemas.chat import Message


# --- Soxta Groq klienti -----------------------------------------------------
def _tool_call(call_id, name, arguments):
    return SimpleNamespace(
        id=call_id,
        function=SimpleNamespace(name=name, arguments=json.dumps(arguments)),
    )


def _response(content=None, tool_calls=None):
    msg = SimpleNamespace(content=content, tool_calls=tool_calls)
    return SimpleNamespace(choices=[SimpleNamespace(message=msg)])


class FakeCompletions:
    def __init__(self):
        self.calls = 0

    async def create(self, **kwargs):
        self.calls += 1
        if self.calls == 1:
            # 1-qadam: calculator tool'ini chaqiradi
            return _response(
                tool_calls=[_tool_call("c1", "calculator", {"expression": "12 * (3 + 4)"})]
            )
        # 2-qadam: observation asosida yakuniy javob
        return _response(content="Hisob natijasi: 84.")


class FakeClient:
    def __init__(self):
        self.chat = SimpleNamespace(completions=FakeCompletions())


# --- Testlar ----------------------------------------------------------------
async def test_tool_registry_directly():
    registry = build_default_registry()
    memory = InMemoryStore()
    ctx = ExecutionContext(session_id="s1", memory=memory)

    res = await registry.execute("calculator", {"expression": "2 ** 10"}, ctx)
    assert res.success and "1024" in res.output, res
    print("✅ ToolRegistry.calculator:", res.output)

    bad = await registry.execute("yoq_tool", {}, ctx)
    assert not bad.success
    print("✅ ToolRegistry noma'lum tool xatosi to'g'ri ushlandi")

    # Calculator xavfsizligi: __import__ kabi narsa ishlamasligi kerak
    danger = await registry.execute("calculator", {"expression": "__import__('os')"}, ctx)
    assert not danger.success
    print("✅ Calculator xavfsiz (ixtiyoriy kod bajarilmaydi)")


async def test_memory_system():
    memory = InMemoryStore()
    await memory.remember("s1", "ism", "Aziz")
    await memory.add_message("s1", Message(role="user", content="salom"))
    assert await memory.recall("s1", "ism") == "Aziz"
    assert (await memory.get_facts("s1")) == {"ism": "Aziz"}
    assert len(await memory.get_history("s1")) == 1
    # Izolyatsiya: boshqa sessiya bo'sh bo'lishi kerak
    assert await memory.recall("s2", "ism") is None
    print("✅ MemorySystem: remember/recall/history/izolyatsiya ishladi")


async def test_web_search_tool():
    # Soxta httpx klienti — DuckDuckGo IA javobini taqlid qiladi (tarmoqsiz).
    class FakeResponse:
        def raise_for_status(self):
            pass

        def json(self):
            return {
                "Heading": "Python",
                "AbstractText": "Python — yuqori darajadagi dasturlash tili.",
                "RelatedTopics": [
                    {"Text": "Python (programming language)", "FirstURL": "https://x/py"},
                ],
            }

    class FakeHttpClient:
        async def get(self, url, params=None):
            return FakeResponse()

    memory = InMemoryStore()
    ctx = ExecutionContext(session_id="s1", memory=memory)
    tool = WebSearchTool(client=FakeHttpClient())
    res = await tool.execute({"query": "python nima"}, ctx)
    assert res.success and "dasturlash tili" in res.output, res
    # Bo'sh so'rov xatosi
    empty = await tool.execute({"query": "  "}, ctx)
    assert not empty.success
    print("✅ WebSearchTool: DuckDuckGo javobini to'g'ri parse qildi")
    print("  ", res.output.replace("\n", " | "))


async def test_code_executor_tool():
    memory = InMemoryStore()
    ctx = ExecutionContext(session_id="s1", memory=memory)
    tool = CodeExecutorTool(timeout_seconds=5.0)

    # 1) Oddiy bajarish
    ok = await tool.execute({"code": "print(sum(range(11)))"}, ctx)
    assert ok.success and ok.output.strip() == "55", ok
    print("✅ CodeExecutor: print(sum(range(11))) →", ok.output)

    # 2) Xato (exception) ushlanadi
    err = await tool.execute({"code": "raise ValueError('boom')"}, ctx)
    assert not err.success and "ValueError" in (err.error or "")
    print("✅ CodeExecutor: exception stderr'da ushlandi")

    # 3) Timeout
    slow = await tool.execute({"code": "while True: pass"}, ctx)
    assert not slow.success and "timeout" in (slow.error or "").lower()
    print("✅ CodeExecutor: cheksiz sikl timeout bilan to'xtatildi")


async def test_planner_react_loop():
    registry = build_default_registry()
    memory = InMemoryStore()
    planner = PlannerAgent(
        registry=registry, memory=memory, client=FakeClient()
    )

    result = await planner.process("12 marta (3+4) nechchi?", [], session_id="s1")

    assert result.agent_name == "PlannerAgent"
    assert "84" in result.content, result.content
    assert len(result.steps) == 1, result.steps
    assert result.steps[0]["tool"] == "calculator"
    assert result.steps[0]["success"] is True
    assert "84" in result.steps[0]["observation"]
    # Suhbat xotiraga yozildimi? (user + assistant = 2 ta xabar)
    history = await memory.get_history("s1")
    assert len(history) == 2, history
    print("✅ PlannerAgent ReAct sikli: tool chaqirdi → observation → yakuniy javob")
    print("   Steps:", result.steps)
    print("   Reply:", result.content)


async def test_planner_streaming():
    registry = build_default_registry()
    memory = InMemoryStore()
    planner = PlannerAgent(registry=registry, memory=memory, client=FakeClient())

    events = []
    async for ev in planner.stream_events("12*(3+4)?", [], session_id="sx"):
        events.append(ev)

    types = [e["type"] for e in events]
    # Kutilgan ketma-ketlik: start → step → token(lar) → done
    assert types[0] == "start", types
    assert types[-1] == "done", types
    assert "step" in types, types
    assert "token" in types, types

    step_ev = next(e for e in events if e["type"] == "step")
    assert step_ev["step"]["tool"] == "calculator"
    assert "84" in step_ev["step"]["observation"]

    streamed_text = "".join(e["content"] for e in events if e["type"] == "token")
    assert "84" in streamed_text, streamed_text
    print("✅ Planner streaming: event ketma-ketligi", types)
    print("   Oqim matni:", repr(streamed_text))


async def main():
    await test_tool_registry_directly()
    await test_memory_system()
    await test_web_search_tool()
    await test_code_executor_tool()
    await test_planner_react_loop()
    await test_planner_streaming()
    print("\n🎉 Barcha offline testlar muvaffaqiyatli o'tdi.")


if __name__ == "__main__":
    asyncio.run(main())
