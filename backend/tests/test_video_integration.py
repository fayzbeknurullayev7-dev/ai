"""/api/v1/video endpointi integratsiya testlari.

KLING_API_KEY bo'sh bo'lgani uchun generate har doim 503 "Kling API key kerak"
qaytaradi (UI tayyor, lekin xizmat hali sozlanmagan).
"""
import pytest

pytestmark = pytest.mark.asyncio


async def test_generate_requires_kling_key(client):
    resp = await client.post(
        "/api/v1/video/generate", json={"prompt": "Dengiz to'lqinlari videosi"}
    )
    assert resp.status_code == 503
    assert "Kling" in resp.json()["detail"]


async def test_generate_empty_prompt_422(client):
    resp = await client.post("/api/v1/video/generate", json={"prompt": ""})
    assert resp.status_code == 422
