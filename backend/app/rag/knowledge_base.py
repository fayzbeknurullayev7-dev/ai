"""
KnowledgeBase — RAG xizmatining yuqori darajadagi fasadi.

Mas'uliyati: hujjatni bo'laklarga ajratish → embedding → vektor omboriga
yozish; so'rovni embedding qilib eng mos bo'laklarni qaytarish. Embedder va
vektor ombori konstruktorda injeksiya qilinadi (Dependency Inversion) —
shu sabab offline (HashingEmbedder + InMemoryVectorStore) ham, production
(GeminiEmbedder) ham bir xil kod bilan ishlaydi.

Hujjat metama'lumoti (sarlavha, bo'laklar soni) shu yerda boshqariladi;
vektor ombori esa faqat vektorlar bilan shug'ullanadi (Separation of Concerns).
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

from app.rag.chunking import split_text
from app.rag.embeddings import BaseEmbedder
from app.rag.vector_store import BaseVectorStore, VectorRecord


@dataclass
class DocumentInfo:
    """Indekslangan hujjat haqida qisqacha ma'lumot."""

    doc_id: str
    title: str
    chunk_count: int
    metadata: Dict[str, Any] = field(default_factory=dict)
    owner: Optional[str] = None


@dataclass
class RetrievedChunk:
    """Qidiruv natijasidagi bitta bo'lak — o'xshashlik balli bilan."""

    text: str
    score: float
    document_id: str
    title: str
    chunk_index: int


class KnowledgeBase:
    def __init__(
        self,
        embedder: BaseEmbedder,
        store: BaseVectorStore,
        chunk_size: int = 512,
        chunk_overlap: int = 64,
    ) -> None:
        self._embedder = embedder
        self._store = store
        self._chunk_size = chunk_size
        self._chunk_overlap = chunk_overlap
        # Hujjat reestri (owner, doc_id) kaliti bo'yicha — ko'p foydalanuvchili
        # izolyatsiya: turli egalar bir xil doc_id ishlatsa ham aralashmaydi.
        self._docs: Dict[Tuple[Optional[str], str], DocumentInfo] = {}

    @property
    def embedder(self) -> BaseEmbedder:
        return self._embedder

    async def add_document(
        self,
        text: str,
        *,
        owner: Optional[str] = None,
        title: Optional[str] = None,
        doc_id: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> DocumentInfo:
        """Matnni bo'laklab indekslaydi. Bo'sh matn xato beradi.

        `owner` berilsa — hujjat faqat shu foydalanuvchining bilim bazasiga
        tegishli bo'ladi (qidiruv/ro'yxat/o'chirish shu egaga izolyatsiya qilinadi).
        """
        if not text or not text.strip():
            raise ValueError("hujjat matni bo'sh")

        chunks = split_text(text, self._chunk_size, self._chunk_overlap)
        if not chunks:
            raise ValueError("matndan bo'lak hosil bo'lmadi")

        doc_id = doc_id or uuid.uuid4().hex
        title = title or f"document-{doc_id[:8]}"
        meta = metadata or {}

        # Mavjud doc_id qayta yuklansa — shu egaga tegishli eski yozuvlarni
        # almashtiramiz (idempotent, boshqa egalarga tegmaydi).
        await self._store.delete_document(doc_id, owner=owner)

        embeddings = await self._embedder.embed(chunks, is_query=False)
        records = [
            VectorRecord(
                id=f"{owner or '_'}:{doc_id}:{i}",
                document_id=doc_id,
                text=chunk,
                embedding=emb,
                chunk_index=i,
                metadata={"title": title, **meta},
                owner=owner,
            )
            for i, (chunk, emb) in enumerate(zip(chunks, embeddings))
        ]
        await self._store.add(records)

        info = DocumentInfo(
            doc_id=doc_id, title=title, chunk_count=len(records),
            metadata=meta, owner=owner,
        )
        self._docs[(owner, doc_id)] = info
        return info

    async def query(
        self, query: str, top_k: int = 4, min_score: float = 0.0,
        *, owner: Optional[str] = None,
    ) -> List[RetrievedChunk]:
        """So'rovga eng mos `top_k` bo'lakni o'xshashlik bo'yicha qaytaradi.

        `owner` berilsa — faqat shu foydalanuvchining hujjatlari bo'yicha qidiradi.
        """
        if not query or not query.strip():
            raise ValueError("so'rov bo'sh")

        q_emb = await self._embedder.embed_one(query, is_query=True)
        results = await self._store.search(q_emb, top_k=top_k, owner=owner)
        return [
            RetrievedChunk(
                text=rec.text,
                score=round(score, 4),
                document_id=rec.document_id,
                title=str(rec.metadata.get("title", "")),
                chunk_index=rec.chunk_index,
            )
            for rec, score in results
            if score >= min_score
        ]

    async def delete_document(
        self, doc_id: str, *, owner: Optional[str] = None
    ) -> bool:
        """Hujjatni o'chiradi (shu egaga tegishli bo'lsa). Topilsa True qaytadi."""
        removed = await self._store.delete_document(doc_id, owner=owner)
        existed = (owner, doc_id) in self._docs
        self._docs.pop((owner, doc_id), None)
        return existed or removed > 0

    async def list_documents(
        self, *, owner: Optional[str] = None
    ) -> List[DocumentInfo]:
        """Hujjatlar ro'yxati. `owner` berilsa — faqat shu egaga tegishlilar."""
        if owner is None:
            return list(self._docs.values())
        return [info for (o, _), info in self._docs.items() if o == owner]

    async def stats(self, *, owner: Optional[str] = None) -> Dict[str, Any]:
        documents = (
            len(self._docs) if owner is None
            else sum(1 for (o, _) in self._docs if o == owner)
        )
        return {
            "documents": documents,
            "chunks": await self._store.count(owner=owner),
            "embedder": type(self._embedder).__name__,
            "dimension": self._embedder.dimension,
        }

    async def clear(self, *, owner: Optional[str] = None) -> None:
        """Bilim bazasini tozalaydi. `owner` berilsa — faqat shu egani."""
        if owner is None:
            await self._store.clear()
            self._docs.clear()
            return
        for (o, doc_id) in [k for k in self._docs if k[0] == owner]:
            await self._store.delete_document(doc_id, owner=owner)
            self._docs.pop((o, doc_id), None)
