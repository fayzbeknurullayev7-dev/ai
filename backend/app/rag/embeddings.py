"""
Embedding provayderlari — matnni vektorga aylantiradi (RAG yadrosi).

Loyiha falsafasi (web_search bilan bir xil):
  • Standart: kalit (API key) talab qilmaydigan, TO'LIQ OFFLINE `HashingEmbedder`.
    Bu feature-hashing orqali leksik (so'z ustma-ustligi) o'xshashlik beradi —
    haqiqiy semantik emas, lekin nol bog'liqlik bilan ishlaydi va deterministik
    (test uchun ideal).
  • Ishlab chiqarish (production): `GEMINI_API_KEY` o'rnatilgan bo'lsa —
    `GeminiEmbedder` haqiqiy semantik embeddinglarni beradi.

SOLID: `BaseEmbedder` abstraksiyasi — KnowledgeBase konkret provayderga emas,
shu interfeysga bog'liq (Dependency Inversion). Yangi provayder qo'shish =
`BaseEmbedder`'ni extend qilish (Open/Closed).
"""
from __future__ import annotations

import hashlib
import math
import re
from abc import ABC, abstractmethod
from typing import List

_TOKEN_RE = re.compile(r"[\w']+", re.UNICODE)


def _l2_normalize(vec: List[float]) -> List[float]:
    norm = math.sqrt(sum(x * x for x in vec))
    if norm == 0.0:
        return vec
    return [x / norm for x in vec]


class BaseEmbedder(ABC):
    """Matn ro'yxatini bir xil o'lchamli vektorlar ro'yxatiga aylantiradi."""

    @property
    @abstractmethod
    def dimension(self) -> int:
        """Vektor o'lchami — vector store shu o'lchamga tayanadi."""
        ...

    @abstractmethod
    async def embed(self, texts: List[str], *, is_query: bool = False) -> List[List[float]]:
        """
        Matnlarni embeddinglarga aylantiradi.

        `is_query` — qidiruv so'rovi (True) yoki hujjat bo'lagi (False).
        Ba'zi provayderlar (Gemini) ikkisiga turli task_type qo'llaydi.
        """
        ...

    async def embed_one(self, text: str, *, is_query: bool = False) -> List[float]:
        return (await self.embed([text], is_query=is_query))[0]


class HashingEmbedder(BaseEmbedder):
    """
    Offline, deterministik feature-hashing embedder (kalitsiz).

    Har bir token MD5 orqali `dimension` o'lchamli vektorning bitta indeksiga
    (va ishorasiga) joylanadi; natija L2-normallashtiriladi. Normallashtirilgan
    vektorlarning skalyar ko'paytmasi = kosinus o'xshashlik.
    """

    def __init__(self, dimension: int = 256) -> None:
        self._dimension = dimension

    @property
    def dimension(self) -> int:
        return self._dimension

    def _embed_text(self, text: str) -> List[float]:
        vec = [0.0] * self._dimension
        for token in _TOKEN_RE.findall(text.lower()):
            digest = hashlib.md5(token.encode("utf-8")).digest()
            idx = int.from_bytes(digest[:4], "big") % self._dimension
            sign = 1.0 if digest[4] & 1 else -1.0  # tasodifiy ishora — to'qnashuvni kamaytiradi
            vec[idx] += sign
        return _l2_normalize(vec)

    async def embed(self, texts: List[str], *, is_query: bool = False) -> List[List[float]]:
        return [self._embed_text(t) for t in texts]


class GeminiEmbedder(BaseEmbedder):
    """
    Google Gemini embeddinglari (`text-embedding-004`, 768 o'lcham).

    Haqiqiy semantik qidiruv. `google.generativeai` faqat ishlash vaqtida import
    qilinadi (modul importi yengil qoladi). genai sinxron — `asyncio.to_thread`
    orqali event loop'ni bloklamasdan chaqiriladi.
    """

    def __init__(self, api_key: str, model: str = "models/text-embedding-004",
                 dimension: int = 768) -> None:
        self._api_key = api_key
        self._model = model
        self._dimension = dimension
        self._configured = False

    @property
    def dimension(self) -> int:
        return self._dimension

    def _ensure_configured(self):
        import google.generativeai as genai  # lazy import
        if not self._configured:
            genai.configure(api_key=self._api_key)
            self._configured = True
        return genai

    def _embed_sync(self, texts: List[str], task_type: str) -> List[List[float]]:
        genai = self._ensure_configured()
        result = genai.embed_content(
            model=self._model, content=texts, task_type=task_type
        )
        emb = result["embedding"]
        # Ro'yxat berilganda ro'yxat-of-ro'yxat, yakka string'da yakka vektor qaytadi.
        if emb and isinstance(emb[0], (int, float)):
            return [emb]  # type: ignore[list-item]
        return emb

    async def embed(self, texts: List[str], *, is_query: bool = False) -> List[List[float]]:
        if not texts:
            return []
        import asyncio
        task_type = "retrieval_query" if is_query else "retrieval_document"
        return await asyncio.to_thread(self._embed_sync, texts, task_type)
