from pydantic import BaseModel, Field
from typing import Any, Dict, List, Optional


class AddDocumentRequest(BaseModel):
    text: str
    title: Optional[str] = None
    doc_id: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)


class DocumentInfoResponse(BaseModel):
    doc_id: str
    title: str
    chunk_count: int
    metadata: Dict[str, Any] = Field(default_factory=dict)


class QueryRequest(BaseModel):
    query: str
    top_k: int = 4
    min_score: float = 0.0


class RetrievedChunkResponse(BaseModel):
    text: str
    score: float
    document_id: str
    title: str
    chunk_index: int


class QueryResponse(BaseModel):
    query: str
    results: List[RetrievedChunkResponse]


class StatsResponse(BaseModel):
    documents: int
    chunks: int
    embedder: str
    dimension: int
