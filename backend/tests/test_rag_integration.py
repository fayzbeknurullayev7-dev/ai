"""
/api/v1/rag endpointlari integratsiya testlari.

Toza, offline KnowledgeBase (HashingEmbedder) conftest orqali injeksiya
qilinadi — tarmoqsiz, kalitsiz, uchma-uch HTTP qatlami sinaladi.

Barcha endpointlar himoyalangan: `auth_client` ro'yxatdan o'tgan foydalanuvchi
tokeni bilan keladi. Bilim bazasi owner = user.id bo'yicha izolyatsiya qilinadi.
"""
import pytest

from tests.conftest import register_user, auth_header

pytestmark = pytest.mark.asyncio


async def test_add_document_and_stats(auth_client):
    resp = await auth_client.post(
        "/api/v1/rag/documents",
        json={"text": "FastAPI tezkor Python backend frameworki.", "title": "BE",
              "doc_id": "be"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["doc_id"] == "be"
    assert body["title"] == "BE"
    assert body["chunk_count"] >= 1

    stats = await auth_client.get("/api/v1/rag/stats")
    assert stats.status_code == 200
    sbody = stats.json()
    assert sbody["documents"] == 1
    assert sbody["chunks"] >= 1
    assert sbody["embedder"] == "HashingEmbedder"


async def test_rag_requires_auth(client):
    """Tokensiz so'rov 401 qaytaradi."""
    resp = await client.get("/api/v1/rag/stats")
    assert resp.status_code == 401


async def test_add_empty_document_400(auth_client):
    resp = await auth_client.post("/api/v1/rag/documents", json={"text": "   "})
    assert resp.status_code == 400


async def test_query_returns_relevant_chunk(auth_client):
    await auth_client.post(
        "/api/v1/rag/documents",
        json={"text": "Python fastapi backend server", "title": "BE", "doc_id": "be"},
    )
    await auth_client.post(
        "/api/v1/rag/documents",
        json={"text": "Flutter dizayn rang logo ikonka", "title": "FE", "doc_id": "fe"},
    )

    resp = await auth_client.post(
        "/api/v1/rag/query", json={"query": "python backend", "top_k": 1}
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["query"] == "python backend"
    assert len(body["results"]) == 1
    top = body["results"][0]
    assert top["document_id"] == "be"
    assert top["score"] > 0
    assert "score" in top and "title" in top and "chunk_index" in top


async def test_query_empty_400(auth_client):
    resp = await auth_client.post("/api/v1/rag/query", json={"query": "  "})
    assert resp.status_code == 400


async def test_list_and_delete_document(auth_client):
    await auth_client.post(
        "/api/v1/rag/documents",
        json={"text": "birinchi hujjat matni", "doc_id": "d1", "title": "D1"},
    )
    await auth_client.post(
        "/api/v1/rag/documents",
        json={"text": "ikkinchi hujjat matni", "doc_id": "d2", "title": "D2"},
    )

    listed = await auth_client.get("/api/v1/rag/documents")
    assert listed.status_code == 200
    ids = {d["doc_id"] for d in listed.json()}
    assert ids == {"d1", "d2"}

    deleted = await auth_client.delete("/api/v1/rag/documents/d1")
    assert deleted.status_code == 200
    assert deleted.json() == {"status": "deleted", "doc_id": "d1"}

    # Endi qidiruvda d1 ko'rinmasligi kerak
    after = await auth_client.get("/api/v1/rag/documents")
    assert {d["doc_id"] for d in after.json()} == {"d2"}


async def test_delete_missing_document_404(auth_client):
    resp = await auth_client.delete("/api/v1/rag/documents/yoq")
    assert resp.status_code == 404


async def test_upload_document(auth_client):
    files = {"file": ("notes.txt", b"Yuklangan fayl matni RAG uchun.", "text/plain")}
    resp = await auth_client.post(
        "/api/v1/rag/upload", files=files, data={"title": "Notes"}
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["title"] == "Notes"
    assert body["chunk_count"] >= 1


async def test_upload_non_utf8_400(auth_client):
    files = {"file": ("bad.bin", b"\xff\xfe\x00binary", "application/octet-stream")}
    resp = await auth_client.post("/api/v1/rag/upload", files=files)
    assert resp.status_code == 400


async def test_rag_isolation_between_tests(auth_client):
    """Har test toza KB oladi — oldingi testdagi hujjatlar ko'rinmaydi."""
    listed = await auth_client.get("/api/v1/rag/documents")
    assert listed.json() == []


async def test_rag_user_isolation(auth_client, client):
    """Bir foydalanuvchi hujjati boshqasiga ko'rinmaydi (owner izolyatsiyasi)."""
    # 1-foydalanuvchi (auth_client) hujjat qo'shadi.
    await auth_client.post(
        "/api/v1/rag/documents",
        json={"text": "Maxfiy loyiha hujjati", "doc_id": "secret", "title": "S"},
    )

    # 2-foydalanuvchi — boshqa token.
    _, token_b = await register_user(client, email="second@example.com")
    hb = auth_header(token_b)

    # 2-foydalanuvchi ro'yxati bo'sh.
    listed_b = await client.get("/api/v1/rag/documents", headers=hb)
    assert listed_b.json() == []

    # 2-foydalanuvchi qidiruvi hech narsa topmaydi.
    q_b = await client.post(
        "/api/v1/rag/query", json={"query": "maxfiy loyiha"}, headers=hb
    )
    assert q_b.json()["results"] == []

    # 2-foydalanuvchi 1-ning hujjatini o'chira olmaydi (404).
    del_b = await client.delete("/api/v1/rag/documents/secret", headers=hb)
    assert del_b.status_code == 404

    # 1-foydalanuvchi hujjati hali ham joyida.
    listed_a = await auth_client.get("/api/v1/rag/documents")
    assert {d["doc_id"] for d in listed_a.json()} == {"secret"}


# ---- PlannerAgent RAG auto-injection ------------------------------------- #
def _system_text(messages) -> str:
    return " ".join(
        m["content"] for m in (messages or []) if m["role"] == "system"
    )


async def test_planner_injects_kb_context(auth_client, planner):
    """KB'da mos hujjat bo'lsa — Planner system promptiga 'Kontekst:' bloki qo'shadi."""
    await auth_client.post(
        "/api/v1/rag/documents",
        json={
            "text": "Nexus AI Agent SOLID prinsiplari asosida qurilgan platforma.",
            "title": "Nexus",
            "doc_id": "nexus",
        },
    )

    resp = await auth_client.post(
        "/api/v1/agent/run",
        json={"message": "Nexus platforma haqida ayt"},
    )
    assert resp.status_code == 200

    # Planner LLM ga yuborgan system xabarlarida kontekst bloki bo'lishi kerak.
    sys_text = _system_text(planner._client.chat.completions.last_messages)
    assert "Kontekst" in sys_text
    assert "Nexus" in sys_text


async def test_planner_injection_silent_when_kb_empty(auth_client, planner):
    """KB bo'sh bo'lsa — injection yo'q, xato ham yo'q (silent)."""
    resp = await auth_client.post(
        "/api/v1/agent/run",
        json={"message": "oddiy savol"},
    )
    assert resp.status_code == 200
    sys_text = _system_text(planner._client.chat.completions.last_messages)
    assert "Kontekst" not in sys_text
