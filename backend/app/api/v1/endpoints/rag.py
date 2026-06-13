from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form

from app.core.dependencies import get_knowledge_base, get_current_user
from app.auth import User
from app.rag.knowledge_base import KnowledgeBase
from app.schemas.rag import (
    AddDocumentRequest,
    DocumentInfoResponse,
    QueryRequest,
    QueryResponse,
    RetrievedChunkResponse,
    StatsResponse,
)

router = APIRouter()


def _to_info(info) -> DocumentInfoResponse:
    return DocumentInfoResponse(
        doc_id=info.doc_id,
        title=info.title,
        chunk_count=info.chunk_count,
        metadata=info.metadata,
    )


@router.post("/documents", response_model=DocumentInfoResponse)
async def add_document(
    request: AddDocumentRequest,
    kb: KnowledgeBase = Depends(get_knowledge_base),
    current: User = Depends(get_current_user),
):
    """Matnli hujjatni joriy foydalanuvchining bilim bazasiga indekslaydi."""
    try:
        info = await kb.add_document(
            request.text,
            owner=current.id,
            title=request.title,
            doc_id=request.doc_id,
            metadata=request.metadata,
        )
        return _to_info(info)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/upload", response_model=DocumentInfoResponse)
async def upload_document(
    file: UploadFile = File(...),
    title: str | None = Form(None),
    kb: KnowledgeBase = Depends(get_knowledge_base),
    current: User = Depends(get_current_user),
):
    """Matnli fayl (.txt/.md) yuklab joriy foydalanuvchi bazasiga indekslaydi."""
    raw = await file.read()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        raise HTTPException(status_code=400, detail="faqat UTF-8 matnli fayllar")
    try:
        info = await kb.add_document(
            text, owner=current.id, title=title or file.filename
        )
        return _to_info(info)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/documents", response_model=list[DocumentInfoResponse])
async def list_documents(
    kb: KnowledgeBase = Depends(get_knowledge_base),
    current: User = Depends(get_current_user),
):
    """Joriy foydalanuvchi indekslagan barcha hujjatlar ro'yxati."""
    docs = await kb.list_documents(owner=current.id)
    return [_to_info(d) for d in docs]


@router.delete("/documents/{doc_id}")
async def delete_document(
    doc_id: str,
    kb: KnowledgeBase = Depends(get_knowledge_base),
    current: User = Depends(get_current_user),
):
    """Hujjat va uning barcha bo'laklarini o'chiradi (faqat o'z bazasidan)."""
    deleted = await kb.delete_document(doc_id, owner=current.id)
    if not deleted:
        raise HTTPException(status_code=404, detail=f"'{doc_id}' topilmadi")
    return {"status": "deleted", "doc_id": doc_id}


@router.post("/query", response_model=QueryResponse)
async def query(
    request: QueryRequest,
    kb: KnowledgeBase = Depends(get_knowledge_base),
    current: User = Depends(get_current_user),
):
    """Joriy foydalanuvchi bilim bazasidan semantik qidiruv."""
    try:
        chunks = await kb.query(
            request.query, top_k=request.top_k, min_score=request.min_score,
            owner=current.id,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return QueryResponse(
        query=request.query,
        results=[
            RetrievedChunkResponse(
                text=c.text,
                score=c.score,
                document_id=c.document_id,
                title=c.title,
                chunk_index=c.chunk_index,
            )
            for c in chunks
        ],
    )


@router.get("/stats", response_model=StatsResponse)
async def stats(
    kb: KnowledgeBase = Depends(get_knowledge_base),
    current: User = Depends(get_current_user),
):
    """Joriy foydalanuvchi bilim bazasi holati."""
    return StatsResponse(**await kb.stats(owner=current.id))
