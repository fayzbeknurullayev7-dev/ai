"""
/api/v1/chat endpointlari integratsiya testlari.

Keyword routing real AgentRouter orqali ishlaydi (soxta agentlar bilan),
shu sababli routing qarori va javob konvertatsiyasi uchma-uch sinaladi.
"""
import pytest

from tests.sse_utils import parse_sse, sse_has_done

pytestmark = pytest.mark.asyncio


async def test_chat_routes_to_coder_by_default(auth_client):
    """Maxsus kalitsiz xabar default CoderAgent'ga boradi."""
    resp = await auth_client.post("/api/v1/chat/", json={"message": "Salom"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["agent_used"] == "CoderAgent"
    assert body["model_used"] == "llama-3.3-70b-versatile"
    assert "Salom" in body["reply"]


async def test_chat_routes_to_media_on_media_keyword(auth_client):
    """Media kaliti (rasm/dizayn) MediaAgent'ni tanlaydi."""
    resp = await auth_client.post(
        "/api/v1/chat/", json={"message": "Bu rasmni tahlil qilib dizayn ber"}
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["agent_used"] == "MediaAgent"
    assert body["model_used"] == "gemini-1.5-flash"


async def test_chat_routes_to_coder_on_code_keyword(auth_client):
    """Kod kaliti (python/function) CoderAgent'ni tanlaydi."""
    resp = await auth_client.post(
        "/api/v1/chat/", json={"message": "python function yozib ber"}
    )
    assert resp.status_code == 200
    assert resp.json()["agent_used"] == "CoderAgent"


async def test_chat_response_schema(auth_client):
    """Javob aniq ChatResponse sxemasiga mos kelishi kerak."""
    resp = await auth_client.post("/api/v1/chat/", json={"message": "test"})
    body = resp.json()
    assert set(body.keys()) == {"reply", "agent_used", "model_used"}


async def test_chat_accepts_history(auth_client):
    """history maydoni qabul qilinadi va xato bermaydi."""
    resp = await auth_client.post(
        "/api/v1/chat/",
        json={
            "message": "davom et",
            "history": [
                {"role": "user", "content": "salom"},
                {"role": "assistant", "content": "salom!"},
            ],
        },
    )
    assert resp.status_code == 200


async def test_chat_validation_error_without_message(auth_client):
    """message majburiy — bo'lmasa 422 validatsiya xatosi."""
    resp = await auth_client.post("/api/v1/chat/", json={})
    assert resp.status_code == 422


async def test_chat_stream_sse_sequence(auth_client):
    """SSE oqimi start → token(lar) → done ketma-ketligini beradi."""
    resp = await auth_client.post(
        "/api/v1/chat/stream", json={"message": "Salom dunyo"}
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/event-stream")

    events = parse_sse(resp.text)
    types = [e["type"] for e in events]
    assert types[0] == "start"
    assert types[-1] == "done"
    assert "token" in types
    assert sse_has_done(resp.text)

    streamed = "".join(e["content"] for e in events if e["type"] == "token")
    assert "Salom" in streamed


async def test_chat_stream_media_route(auth_client):
    """Stream ham routing qiladi: media kaliti MediaAgent'ni belgilaydi."""
    resp = await auth_client.post(
        "/api/v1/chat/stream", json={"message": "rasmni tasvirla"}
    )
    events = parse_sse(resp.text)
    start = next(e for e in events if e["type"] == "start")
    assert start["agent"] == "MediaAgent"
