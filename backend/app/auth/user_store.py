"""
Foydalanuvchi ombori — ro'yxatdan o'tgan foydalanuvchilarni saqlaydi.

SOLID: `BaseUserStore` abstraksiyasi (Dependency Inversion). Standart
`InMemoryUserStore` — RAM ichida. Production'da bir xil interfeysni amalga
oshirib Redis/Postgres backendi qo'shilishi mumkin (Open/Closed). Memory
System (BaseMemory) bilan bir xil pattern.
"""
from __future__ import annotations

import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Dict, Optional


@dataclass
class User:
    """Ro'yxatdan o'tgan foydalanuvchi (parol hash bilan)."""

    id: str
    email: str
    password_hash: str
    full_name: str = ""
    created_at: float = 0.0
    metadata: Dict[str, str] = field(default_factory=dict)


class BaseUserStore(ABC):
    @abstractmethod
    async def create(
        self, email: str, password_hash: str, full_name: str = "", *,
        created_at: float = 0.0
    ) -> User:
        ...

    @abstractmethod
    async def get_by_email(self, email: str) -> Optional[User]:
        ...

    @abstractmethod
    async def get_by_id(self, user_id: str) -> Optional[User]:
        ...

    @abstractmethod
    async def count(self) -> int:
        ...


class EmailAlreadyExists(Exception):
    """Shu email bilan foydalanuvchi allaqachon mavjud."""


def _normalize_email(email: str) -> str:
    return email.strip().lower()


class InMemoryUserStore(BaseUserStore):
    """RAM ichidagi foydalanuvchi ombori. Email — unikal kalit."""

    def __init__(self) -> None:
        self._by_email: Dict[str, User] = {}
        self._by_id: Dict[str, User] = {}

    async def create(
        self, email: str, password_hash: str, full_name: str = "", *,
        created_at: float = 0.0
    ) -> User:
        norm = _normalize_email(email)
        if norm in self._by_email:
            raise EmailAlreadyExists(email)
        user = User(
            id=uuid.uuid4().hex,
            email=norm,
            password_hash=password_hash,
            full_name=full_name,
            created_at=created_at,
        )
        self._by_email[norm] = user
        self._by_id[user.id] = user
        return user

    async def get_by_email(self, email: str) -> Optional[User]:
        return self._by_email.get(_normalize_email(email))

    async def get_by_id(self, user_id: str) -> Optional[User]:
        return self._by_id.get(user_id)

    async def count(self) -> int:
        return len(self._by_id)
