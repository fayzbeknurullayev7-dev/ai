from collections import defaultdict
from typing import Dict, List, Optional
from app.memory.base_memory import BaseMemory
from app.schemas.chat import Message


class InMemoryStore(BaseMemory):
    """
    Jarayon ichidagi (process-local) xotira — Redis talab qilmaydi.
    Development va testlar uchun standart implementatsiya.

    Eslatma: serverni qayta ishga tushirsangiz, xotira tozalanadi.
    Production / ko'p instansiya uchun RedisMemory ishlating.
    """

    def __init__(self) -> None:
        self._conversations: Dict[str, List[Message]] = defaultdict(list)
        self._facts: Dict[str, Dict[str, str]] = defaultdict(dict)

    async def add_message(self, session_id: str, message: Message) -> None:
        self._conversations[session_id].append(message)

    async def get_history(self, session_id: str, limit: int = 20) -> List[Message]:
        return self._conversations[session_id][-limit:]

    async def remember(self, session_id: str, key: str, value: str) -> None:
        self._facts[session_id][key] = value

    async def recall(self, session_id: str, key: str) -> Optional[str]:
        return self._facts[session_id].get(key)

    async def get_facts(self, session_id: str) -> dict:
        return dict(self._facts[session_id])

    async def clear(self, session_id: str) -> None:
        self._conversations.pop(session_id, None)
        self._facts.pop(session_id, None)
