import json
import re
from typing import Any, AsyncIterator, Dict, List, Optional

from groq import AsyncGroq

from app.agents.base_agent import BaseAgent, AgentResult
from app.core.config import settings
from app.memory.base_memory import BaseMemory
from app.schemas.chat import Message
from app.tools.base_tool import ExecutionContext
from app.tools.registry import ToolRegistry

SYSTEM_PROMPT = """Sen Nexus AI — yordamchi AI assistant.

Foydalanuvchi bilan tabiiy suhbatlash; savol va iltimoslariga aniq, foydali
javob ber. Sen umumiy yordamchisan — dasturchi emas.

Asosiy qoidalar:
1. Oddiy suhbatda KOD YOZMA. Faqat foydalanuvchi aniq so'raganda ("kod yozib
   ber", "funksiya yoz", "script yoz" va h.k.) kod yoz.
2. Kerak bo'lganda mavjud tool'lardan foydalan (aniq hisob-kitob, vaqt/sana,
   qidiruv, xotira): murakkab vazifani qadamlarga bo'lib, Thought → Action →
   Observation tarzida ishla, so'ng yakuniy javobni yoz.
3. Tool chaqirish shart bo'lmasa — to'g'ridan-to'g'ri javob ber.

Javoblarni o'zbek tilida, aniq va qisqa yoz; kod va identifikatorlar ingliz
tilida bo'lsin."""


def _chunk_text(text: str) -> List[str]:
    """Yakuniy javobni "yozilayotgan" effekt uchun so'zlarga bo'ladi."""
    if not text:
        return []
    return re.findall(r"\S+\s*", text)


class PlannerAgent(BaseAgent):
    """
    Tool Calling + Memory'dan foydalanadigan reja tuzuvchi agent.

    Groq'ning OpenAI-mos function-calling API'si orqali ReAct siklini yuritadi.
    Yagona manba — `_run_events` async generatori: u start/step/token/done
    eventlarini chiqaradi. process(), stream(), stream_events() shu generatordan
    quriladi (DRY).

    LLM klienti konstruktorda injeksiya qilinishi mumkin (offline test uchun).
    """

    def __init__(
        self,
        registry: ToolRegistry,
        memory: BaseMemory,
        max_steps: int = 6,
        client: Optional[Any] = None,
        knowledge_base: Optional[Any] = None,
        rag_top_k: int = 3,
    ) -> None:
        self._client = client or AsyncGroq(api_key=settings.GROQ_API_KEY)
        self._model = "llama-3.3-70b-versatile"
        self._registry = registry
        self._memory = memory
        self._max_steps = max_steps
        # RAG auto-injection: bo'lsa — har so'rovda bilim bazasidan kontekst tortiladi.
        self._kb = knowledge_base
        self._rag_top_k = rag_top_k

    @property
    def name(self) -> str:
        return "PlannerAgent"

    async def _build_messages(
        self, message: str, history: List[Message], session_id: str
    ) -> List[Dict[str, Any]]:
        msgs: List[Dict[str, Any]] = [{"role": "system", "content": SYSTEM_PROMPT}]

        facts = await self._memory.get_facts(session_id)
        if facts:
            fact_lines = "\n".join(f"- {k}: {v}" for k, v in facts.items())
            msgs.append(
                {
                    "role": "system",
                    "content": f"Foydalanuvchi haqida eslab qolingan faktlar:\n{fact_lines}",
                }
            )

        # RAG auto-injection: bilim bazasidan dolzarb kontekst (silent — xato chiqarmaydi).
        # session_id = user.id → har foydalanuvchi faqat o'z bilim bazasidan kontekst oladi.
        context = await self._retrieve_context(message, owner=session_id)
        if context:
            msgs.append(
                {
                    "role": "system",
                    "content": (
                        "Kontekst (loyiha bilim bazasidan olingan, javobda "
                        "shulardan foydalan):\n" + context
                    ),
                }
            )

        for h in history[-10:]:
            msgs.append({"role": h.role, "content": h.content})
        msgs.append({"role": "user", "content": message})
        return msgs

    async def _retrieve_context(
        self, message: str, owner: Optional[str] = None
    ) -> Optional[str]:
        """
        Bilim bazasidan so'rovga mos top-k bo'lakni tortadi va system bloki uchun
        formatlaydi. `owner` berilsa — faqat shu foydalanuvchining hujjatlari.
        KB ulanmagan bo'lsa, natija yo'q bo'lsa yoki har qanday xato yuz bersa —
        None qaytaradi (silent, agent ishini buzmaydi).
        """
        if self._kb is None:
            return None
        try:
            chunks = await self._kb.query(message, top_k=self._rag_top_k, owner=owner)
        except Exception:
            return None
        if not chunks:
            return None
        lines = []
        for i, ch in enumerate(chunks, 1):
            src = getattr(ch, "title", "") or getattr(ch, "document_id", "")
            lines.append(f"[{i}] ({src}) {ch.text}")
        return "\n".join(lines)

    # ---- YAGONA MANBA: event generatori -------------------------------------
    async def _run_events(
        self, message: str, history: List[Message], session_id: str
    ) -> AsyncIterator[Dict[str, Any]]:
        context = ExecutionContext(session_id=session_id, memory=self._memory)
        await self._memory.add_message(
            session_id, Message(role="user", content=message)
        )

        messages = await self._build_messages(message, history, session_id)
        tools = self._registry.schemas()
        final_content = ""

        yield {"type": "start", "agent": self.name, "model": self._model}

        for step_idx in range(1, self._max_steps + 1):
            response = await self._client.chat.completions.create(
                model=self._model,
                messages=messages,
                tools=tools,
                tool_choice="auto",
                temperature=0.2,
                max_tokens=2048,
            )
            msg = response.choices[0].message
            tool_calls = getattr(msg, "tool_calls", None)

            if not tool_calls:
                final_content = msg.content or ""
                for tok in _chunk_text(final_content):
                    yield {"type": "token", "content": tok}
                break

            messages.append(
                {
                    "role": "assistant",
                    "content": msg.content or "",
                    "tool_calls": [
                        {
                            "id": tc.id,
                            "type": "function",
                            "function": {
                                "name": tc.function.name,
                                "arguments": tc.function.arguments,
                            },
                        }
                        for tc in tool_calls
                    ],
                }
            )

            for tc in tool_calls:
                try:
                    args = json.loads(tc.function.arguments or "{}")
                except json.JSONDecodeError:
                    args = {}
                result = await self._registry.execute(tc.function.name, args, context)
                observation = result.as_observation()
                step = {
                    "step": step_idx,
                    "tool": tc.function.name,
                    "args": args,
                    "observation": observation,
                    "success": result.success,
                }
                # Tool bajarilishi BILANOQ event chiqadi (real vaqt).
                yield {"type": "step", "step": step}
                messages.append(
                    {"role": "tool", "tool_call_id": tc.id, "content": observation}
                )
        else:
            final_content = (
                "Vazifa belgilangan qadamlar ichida yakunlanmadi. "
                "Iltimos, so'rovni soddalashtiring yoki bo'laklarga bo'ling."
            )
            for tok in _chunk_text(final_content):
                yield {"type": "token", "content": tok}

        await self._memory.add_message(
            session_id, Message(role="assistant", content=final_content)
        )
        yield {"type": "done"}

    # ---- Generatordan quriladigan ommaviy metodlar --------------------------
    async def process(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AgentResult:
        content_parts: List[str] = []
        steps: List[Dict[str, Any]] = []
        async for ev in self._run_events(message, history, session_id):
            if ev["type"] == "token":
                content_parts.append(ev["content"])
            elif ev["type"] == "step":
                steps.append(ev["step"])
        return AgentResult(
            content="".join(content_parts),
            agent_name=self.name,
            model_name=self._model,
            steps=steps,
        )

    async def stream_events(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AsyncIterator[Dict[str, Any]]:
        async for ev in self._run_events(message, history, session_id):
            yield ev

    async def stream(
        self, message: str, history: List[Message], session_id: str = "default"
    ) -> AsyncIterator[str]:
        # Matnli oqim (eski iste'molchilar uchun): qadamlarni belgilab, matnni uzatadi.
        async for ev in self._run_events(message, history, session_id):
            if ev["type"] == "token":
                yield ev["content"]
            elif ev["type"] == "step":
                s = ev["step"]
                yield f"🔧 [{s['tool']}] → {s['observation']}\n"
