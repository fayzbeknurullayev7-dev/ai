"""RAG (Retrieval-Augmented Generation) / vektor qidiruv paketi."""
from app.rag.embeddings import BaseEmbedder, HashingEmbedder, GeminiEmbedder
from app.rag.vector_store import BaseVectorStore, InMemoryVectorStore, VectorRecord
from app.rag.knowledge_base import KnowledgeBase, DocumentInfo, RetrievedChunk
from app.rag.chunking import split_text
from app.core.config import settings

__all__ = [
    "BaseEmbedder",
    "HashingEmbedder",
    "GeminiEmbedder",
    "BaseVectorStore",
    "InMemoryVectorStore",
    "VectorRecord",
    "KnowledgeBase",
    "DocumentInfo",
    "RetrievedChunk",
    "split_text",
    "build_default_embedder",
    "build_default_knowledge_base",
]


def build_default_embedder() -> BaseEmbedder:
    """
    GEMINI_API_KEY o'rnatilgan bo'lsa — haqiqiy semantik GeminiEmbedder,
    aks holda kalitsiz, offline HashingEmbedder (web_search bilan bir xil pattern).
    """
    if settings.GEMINI_API_KEY:
        return GeminiEmbedder(api_key=settings.GEMINI_API_KEY)
    return HashingEmbedder()


def build_default_knowledge_base() -> KnowledgeBase:
    """Standart bilim bazasi: tanlangan embedder + RAM ichidagi vektor ombori."""
    return KnowledgeBase(
        embedder=build_default_embedder(),
        store=InMemoryVectorStore(),
    )
