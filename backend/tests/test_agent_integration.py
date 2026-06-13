"""
/api/v1/agent endpointlari integratsiya testlari.

REAL PlannerAgent (injeksiya qilingan FakeClient bilan) ishlatiladi, shu
sababli ReAct sikli, tool bajarilishi va xotira yozuvi HTTP qatlami orqali
uchma-uch sinaladi.

Barcha endpointlar himoyalangan: `auth_client` ro'yxatdan o'tgan foydalanuvchi
tokeni bilan keladi. Sessiya = user.id, shuning uchun xotira foydalanuvchiga
izolyatsiya qilinadi (path'da session_id yo'q).
"""
import pytest

from tests.conftest import register_user, auth_header
from tests.sse_utils import parse_sse, sse_has_done

pytestmark = pytest.mark.asyncio


# ---- /agent/run ----------------------------------------------------------- #
async def test_agent_run_react_loop(auth_client):
    """ReAct sikli: calculator tool chaqiriladi → yakuniy javob 84."""
    resp = await auth_client.post(
        "/api/v1/agent/run",
        json={"message": "12 marta (3+4) nechchi?"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["agent_used"] == "PlannerAgent"
    assert "84" in body["reply"]
    assert len(body["steps"]) == 1

    step = body["steps"][0]
    assert step["tool"] == "calculator"
    assert step["success"] is True
    assert step["step"] == 1
    assert "84" in step["observation"]
    assert step["args"] == {"expression": "12 * (3 + 4)"}


async def test_agent_requires_auth(client):
    """Tokensiz so'rov 401 qaytaradi (himoyalangan endpoint)."""
    resp = await client.post("/api/v1/agent/run", json={"message": "salom"})
    assert resp.status_code == 401


async def test_agent_run_persists_history(auth_client):
    """Suhbat xotiraga yoziladi — keyin /memory orqali ko'rinadi."""
    await auth_client.post("/api/v1/agent/run", json={"message": "12*(3+4)?"})
    resp = await auth_client.get("/api/v1/agent/memory")
    assert resp.status_code == 200
    body = resp.json()
    # user + assistant = 2 ta xabar
    assert body["history_length"] == 2
    assert body["session_id"] == auth_client.user["id"]


async def test_agent_run_validation_error(auth_client):
    """message yo'q bo'lsa 422."""
    resp = await auth_client.post("/api/v1/agent/run", json={})
    assert resp.status_code == 422


# ---- /agent/stream -------------------------------------------------------- #
async def test_agent_stream_event_sequence(auth_client):
    """SSE: start → step → token(lar) → done."""
    resp = await auth_client.post(
        "/api/v1/agent/stream",
        json={"message": "12*(3+4)?"},
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/event-stream")

    events = parse_sse(resp.text)
    types = [e["type"] for e in events]
    assert types[0] == "start"
    assert types[-1] == "done"
    assert "step" in types
    assert "token" in types
    assert sse_has_done(resp.text)

    step_ev = next(e for e in events if e["type"] == "step")
    assert step_ev["step"]["tool"] == "calculator"
    assert "84" in step_ev["step"]["observation"]

    streamed = "".join(e["content"] for e in events if e["type"] == "token")
    assert "84" in streamed


async def test_agent_stream_start_metadata(auth_client):
    """start eventi agent va model nomini bildiradi."""
    resp = await auth_client.post(
        "/api/v1/agent/stream",
        json={"message": "12*(3+4)?"},
    )
    events = parse_sse(resp.text)
    start = events[0]
    assert start["type"] == "start"
    assert start["agent"] == "PlannerAgent"
    assert "model" in start


# ---- /agent/tools --------------------------------------------------------- #
async def test_list_tools(auth_client):
    """Ro'yxatdan o'tgan tool'lar function-calling sxemasi bilan qaytadi."""
    resp = await auth_client.get("/api/v1/agent/tools")
    assert resp.status_code == 200
    tools = resp.json()["tools"]
    assert isinstance(tools, list) and len(tools) > 0

    names = {t["function"]["name"] for t in tools}
    assert "calculator" in names
    # Har bir sxema OpenAI function-calling formatiga mos
    for t in tools:
        assert t["type"] == "function"
        assert "name" in t["function"]
        assert "parameters" in t["function"]


# ---- /agent/memory -------------------------------------------------------- #
async def test_memory_empty_session(auth_client):
    """Hech qachon ishlatilmagan foydalanuvchi xotirasi bo'sh holatda."""
    resp = await auth_client.get("/api/v1/agent/memory")
    assert resp.status_code == 200
    body = resp.json()
    assert body["facts"] == {}
    assert body["history_length"] == 0


async def test_memory_clear(auth_client):
    """DELETE /memory joriy foydalanuvchi xotirasini tozalaydi."""
    # Avval suhbat hosil qilamiz
    await auth_client.post("/api/v1/agent/run", json={"message": "12*(3+4)?"})
    before = await auth_client.get("/api/v1/agent/memory")
    assert before.json()["history_length"] == 2

    # Tozalaymiz
    resp = await auth_client.delete("/api/v1/agent/memory")
    assert resp.status_code == 200
    assert resp.json()["status"] == "cleared"

    after = await auth_client.get("/api/v1/agent/memory")
    assert after.json()["history_length"] == 0


async def test_memory_user_isolation(auth_client, client):
    """Turli foydalanuvchilar bir-birining xotirasini ko'rmaydi."""
    # 1-foydalanuvchi (auth_client) suhbat qiladi.
    await auth_client.post("/api/v1/agent/run", json={"message": "12*(3+4)?"})
    a = await auth_client.get("/api/v1/agent/memory")
    assert a.json()["history_length"] == 2

    # 2-foydalanuvchi — boshqa token, toza xotira.
    _, token_b = await register_user(client, email="second@example.com")
    b = await client.get(
        "/api/v1/agent/memory", headers=auth_header(token_b)
    )
    assert b.status_code == 200
    assert b.json()["history_length"] == 0
    assert b.json()["session_id"] != auth_client.user["id"]
