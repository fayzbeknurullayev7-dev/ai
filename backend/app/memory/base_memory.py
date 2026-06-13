from abc import ABC, abstractmethod
from typing import List, Optional
from app.schemas.chat import Message


class BaseMemory(ABC):
    """
    Memory System abstraksiyasi (SOLID — Dependency Inversion).

    Ikki turdagi xotira:
      • Conversation buffer — qisqa muddatli suhbat tarixi (Message ro'yxati).
      • Key-value facts     — uzoq muddatli "esda qoladigan" faktlar.

    Har bir operatsiya `session_id` bo'yicha izolyatsiya qilinadi, shuning
    uchun bitta backend ko'p foydalanuvchiga xizmat qila oladi.
    """

    # ---- Conversation buffer (short-term) -------------------------------
    @abstractmethod
    async def add_message(self, session_id: str, message: Message) -> None:
        ...

    @abstractmethod
    async def get_history(self, session_id: str, limit: int = 20) -> List[Message]:
        ...

    # ---- Key-value facts (long-term) ------------------------------------
    @abstractmethod
    async def remember(self, session_id: str, key: str, value: str) -> None:
        ...

    @abstractmethod
    async def recall(self, session_id: str, key: str) -> Optional[str]:
        ...

    @abstractmethod
    async def get_facts(self, session_id: str) -> dict:
        ...

    # ---- Lifecycle ------------------------------------------------------
    @abstractmethod
    async def clear(self, session_id: str) -> None:
        ...
