"""
Vektor ombori (vector store) — embeddinglarni saqlaydi va kosinus o'xshashlik
bo'yicha eng yaqin bo'laklarni qaytaradi.

SOLID: `BaseVectorStore` abstraksiyasi. Standart `InMemoryVectorStore` —
sof Python (numpy'siz) kosinus qidiruv. Kelajakda Redis/Chroma/pgvector
backendini shu interfeysni amalga oshirib qo'shish mumkin (Open/Closed).
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple


@dataclass
class VectorRecord:
    """Bitta indekslangan bo'lak — matn + embedding + metama'lumot.

    `owner` — yozuv egasi (odatda user.id). Ko'p foydalanuvchili izolyatsiya
    shu maydon orqali amalga oshadi: qidiruv/o'chirish faqat egaga tegishli
    yozuvlar ustida ishlaydi. `None` — eski (egasiz) global yozuvlar.
    """

    id: str
    document_id: str
    text: str
    embedding: List[float]
    chunk_index: int = 0
    metadata: Dict[str, Any] = field(default_factory=dict)
    owner: Optional[str] = None


def _cosine(a: List[float], b: List[float]) -> float:
    """
    Kosinus o'xshashlik. Embedderlar vektorlarni L2-normallashtirib beradi,
    shuning uchun bu odatda oddiy skalyar ko'paytma; baribir umumiy holatni
    qo'llab-quvvatlash uchun normaga bo'lamiz.
    """
    dot = 0.0
    na = 0.0
    nb = 0.0
    for x, y in zip(a, b):
        dot += x * y
        na += x * x
        nb += y * y
    if na == 0.0 or nb == 0.0:
        return 0.0
    return dot / (na ** 0.5 * nb ** 0.5)


class BaseVectorStore(ABC):
    @abstractmethod
    async def add(self, records: List[VectorRecord]) -> None:
        ...

    @abstractmethod
    async def search(
        self, query_embedding: List[float], top_k: int = 4,
        *, owner: Optional[str] = None
    ) -> List[Tuple[VectorRecord, float]]:
        """
        Eng o'xshash `top_k` yozuvni (yozuv, ball) juftliklari sifatida qaytaradi.
        `owner` berilsa — faqat shu egaga tegishli yozuvlar bo'yicha qidiradi
        (ko'p foydalanuvchili izolyatsiya). `None` — barcha yozuvlar (eski xatti-harakat).
        """
        ...

    @abstractmethod
    async def delete_document(
        self, document_id: str, *, owner: Optional[str] = None
    ) -> int:
        """Hujjatga tegishli barcha yozuvlarni o'chiradi; o'chirilgan soni qaytadi.

        `owner` berilsa — faqat shu egaga tegishli yozuvlar o'chadi.
        """
        ...

    @abstractmethod
    async def clear(self) -> None:
        ...

    @abstractmethod
    async def count(self, *, owner: Optional[str] = None) -> int:
        ...


class InMemoryVectorStore(BaseVectorStore):
    """RAM ichidagi vektor ombori — sof Python kosinus qidiruv."""

    def __init__(self) -> None:
        self._records: List[VectorRecord] = []

    async def add(self, records: List[VectorRecord]) -> None:
        self._records.extend(records)

    async def search(
        self, query_embedding: List[float], top_k: int = 4,
        *, owner: Optional[str] = None
    ) -> List[Tuple[VectorRecord, float]]:
        if not self._records or top_k <= 0:
            return []
        candidates = (
            self._records if owner is None
            else [r for r in self._records if r.owner == owner]
        )
        scored = [
            (rec, _cosine(query_embedding, rec.embedding)) for rec in candidates
        ]
        scored.sort(key=lambda pair: pair[1], reverse=True)
        return scored[:top_k]

    async def delete_document(
        self, document_id: str, *, owner: Optional[str] = None
    ) -> int:
        def _keep(r: VectorRecord) -> bool:
            # O'chiriladigan: doc_id mos VA (owner berilmagan yoki owner mos).
            matches = r.document_id == document_id and (
                owner is None or r.owner == owner
            )
            return not matches

        before = len(self._records)
        self._records = [r for r in self._records if _keep(r)]
        return before - len(self._records)

    async def clear(self) -> None:
        self._records = []

    async def count(self, *, owner: Optional[str] = None) -> int:
        if owner is None:
            return len(self._records)
        return sum(1 for r in self._records if r.owner == owner)
