"""Health endpointlari integratsiya testlari."""
import pytest

pytestmark = pytest.mark.asyncio


async def test_root_health(client):
    """Ildiz /health — ilova darajasidagi tekshiruv."""
    resp = await client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["service"] == "nexus-ai-agent"


async def test_v1_health(client):
    """/api/v1/health/ — versiyalangan router orqali."""
    resp = await client.get("/api/v1/health/")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}
