"""
RAG yadrosi uchun offline unit testlar — tarmoqsiz, kalitsiz (HashingEmbedder).

Embedder, vektor ombori, chunking, KnowledgeBase fasadi va KnowledgeSearchTool
mustaqil sinaladi.
"""
import pytest

from app.rag import HashingEmbedder, InMemoryVectorStore, KnowledgeBase, split_text
from app.rag.vector_store import VectorRecord
from app.tools.knowledge_tool import KnowledgeSearchTool
from app.tools.base_tool import ExecutionContext
from app.memory import InMemoryStore

pytestmark = pytest.mark.asyncio


# ---- HashingEmbedder ------------------------------------------------------ #
async def test_hashing_embedder_deterministic_and_dimension():
    emb = HashingEmbedder(dimension=128)
    a = await emb.embed_one("flutter riverpod state management")
    b = await emb.embed_one("flutter riverpod state management")
    assert len(a) == 128
    assert a == b  # deterministik

    # L2-normallashtirilgan → uzunligi ~1
    norm = sum(x * x for x in a) ** 0.5
    assert abs(norm - 1.0) < 1e-6


async def test_hashing_embedder_similarity_orders_by_overlap():
    emb = HashingEmbedder()

    def cos(u, v):
        return sum(x * y for x, y in zip(u, v))

    q = await emb.embed_one("python fastapi backend")
    close = await emb.embed_one("python fastapi backend server")
    far = await emb.embed_one("rang dizayn logo ikonka")
    assert cos(q, close) > cos(q, far)


# ---- chunking ------------------------------------------------------------- #
async def test_split_text_paragraphs_and_overlap():
    text = "Birinchi paragraf.\n\nIkkinchi paragraf biroz uzunroq matn."
    chunks = split_text(text, chunk_size=100, overlap=10)
    assert chunks == ["Birinchi paragraf.", "Ikkinchi paragraf biroz uzunroq matn."]


async def test_split_text_long_paragraph_is_chunked():
    text = " ".join(f"so'z{i}" for i in range(200))
    chunks = split_text(text, chunk_size=80, overlap=16)
    assert len(chunks) > 1
    assert all(len(c) <= 80 + 16 for c in chunks)


async def test_split_text_invalid_overlap():
    with pytest.raises(ValueError):
        split_text("salom", chunk_size=10, overlap=10)


# ---- InMemoryVectorStore -------------------------------------------------- #
async def test_vector_store_search_ordering_and_delete():
    store = InMemoryVectorStore()
    await store.add([
        VectorRecord(id="d1:0", document_id="d1", text="a", embedding=[1.0, 0.0]),
        VectorRecord(id="d2:0", document_id="d2", text="b", embedding=[0.0, 1.0]),
    ])
    results = await store.search([1.0, 0.0], top_k=2)
    assert results[0][0].document_id == "d1"
    assert results[0][1] > results[1][1]
    assert await store.count() == 2

    deleted = await store.delete_document("d1")
    assert deleted == 1
    assert await store.count() == 1


# ---- KnowledgeBase -------------------------------------------------------- #
@pytest.fixture
def kb():
    return KnowledgeBase(embedder=HashingEmbedder(), store=InMemoryVectorStore())


async def test_kb_add_and_query(kb):
    await kb.add_document(
        "FastAPI Python uchun tezkor backend frameworki.",
        title="Backend",
        doc_id="doc-backend",
    )
    await kb.add_document(
        "Flutter mobil ilovalar uchun UI toolkit. Dizayn va ranglar.",
        title="Frontend",
        doc_id="doc-frontend",
    )

    results = await kb.query("python backend framework", top_k=1)
    assert len(results) == 1
    assert results[0].document_id == "doc-backend"
    assert results[0].title == "Backend"
    assert results[0].score > 0


async def test_kb_reindex_is_idempotent(kb):
    await kb.add_document("matn bir", doc_id="d", title="v1")
    info = await kb.add_document("boshqa matn ikki uch", doc_id="d", title="v2")
    docs = await kb.list_documents()
    assert len(docs) == 1  # qayta yuklash dublikat hosil qilmaydi
    assert docs[0].title == "v2"
    assert info.chunk_count >= 1


async def test_kb_delete_and_stats(kb):
    await kb.add_document("salom dunyo", doc_id="d1")
    stats = await kb.stats()
    assert stats["documents"] == 1
    assert stats["chunks"] >= 1
    assert stats["embedder"] == "HashingEmbedder"

    assert await kb.delete_document("d1") is True
    assert await kb.delete_document("yoq") is False
    assert (await kb.stats())["documents"] == 0


async def test_kb_empty_document_rejected(kb):
    with pytest.raises(ValueError):
        await kb.add_document("   ")


# ---- KnowledgeSearchTool -------------------------------------------------- #
async def test_knowledge_search_tool(kb):
    await kb.add_document(
        "Nexus AI Agent SOLID prinsiplari asosida qurilgan ko'p agentli platforma.",
        title="Nexus",
        doc_id="nexus",
        owner="s1",
    )
    tool = KnowledgeSearchTool(kb)
    ctx = ExecutionContext(session_id="s1", memory=InMemoryStore())

    res = await tool.execute({"query": "Nexus platforma agentlari"}, ctx)
    assert res.success
    assert "Nexus" in res.output

    # Boshqa foydalanuvchi (owner) bu hujjatni ko'rmaydi — izolyatsiya.
    ctx_other = ExecutionContext(session_id="s2", memory=InMemoryStore())
    isolated = await tool.execute({"query": "Nexus platforma agentlari"}, ctx_other)
    assert isolated.success
    assert "topilmadi" in isolated.output.lower()

    empty = await tool.execute({"query": "  "}, ctx)
    assert not empty.success


async def test_knowledge_search_tool_no_results(kb):
    tool = KnowledgeSearchTool(kb)
    ctx = ExecutionContext(session_id="s1", memory=InMemoryStore())
    res = await tool.execute({"query": "hech narsa"}, ctx)
    # Bo'sh baza — muvaffaqiyatli, lekin "topilmadi" xabari
    assert res.success
    assert "topilmadi" in res.output.lower()
