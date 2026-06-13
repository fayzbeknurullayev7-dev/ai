import json
from typing import List, Optional
from app.memory.base_memory import BaseMemory
from app.schemas.chat import Message

try:
    import redis.asyncio as aioredis
except ImportError:  # pragma: no cover - redis ixtiyoriy
    aioredis = None


class RedisMemory(BaseMemory):
    """
    Redis bilan saqlanadigan xotira — ko'p instansiya / qayta ishga
    tushirishga chidamli (persistent). RedisMemory bir xil interfeysni
    (BaseMemory) bajaradi, shuning uchun InMemoryStore o'rniga shaffof
    almashtirilishi mumkin (Liskov Substitution).

    Kalit sxemasi:
        nexus:{session_id}:history   → LIST (har element JSON Message)
        nexus:{session_id}:facts     → HASH (key → value)
    """

    def __init__(self, url: str, ttl_seconds: int = 60 * 60 * 24) -> None:
        if aioredis is None:
            raise RuntimeError(
                "redis paketi o'rnatilmagan. `pip install redis` qiling "
                "yoki InMemoryStore ishlating."
            )
        self._redis = aioredis.from_url(url, decode_responses=True)
        self._ttl = ttl_seconds

    def _hist_key(self, session_id: str) -> str:
        return f"nexus:{session_id}:history"

    def _facts_key(self, session_id: str) -> str:
        return f"nexus:{session_id}:facts"

    async def add_message(self, session_id: str, message: Message) -> None:
        key = self._hist_key(session_id)
        await self._redis.rpush(key, message.model_dump_json())
        await self._redis.expire(key, self._ttl)

    async def get_history(self, session_id: str, limit: int = 20) -> List[Message]:
        raw = await self._redis.lrange(self._hist_key(session_id), -limit, -1)
        return [Message(**json.loads(item)) for item in raw]

    async def remember(self, session_id: str, key: str, value: str) -> None:
        fkey = self._facts_key(session_id)
        await self._redis.hset(fkey, key, value)
        await self._redis.expire(fkey, self._ttl)

    async def recall(self, session_id: str, key: str) -> Optional[str]:
        return await self._redis.hget(self._facts_key(session_id), key)

    async def get_facts(self, session_id: str) -> dict:
        return await self._redis.hgetall(self._facts_key(session_id))

    async def clear(self, session_id: str) -> None:
        await self._redis.delete(
            self._hist_key(session_id), self._facts_key(session_id)
        )
