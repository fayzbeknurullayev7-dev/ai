"""/api/v1/slides endpointlari integratsiya testlari.

GROQ_API_KEY o'rnatilmagani uchun generate_outline OFFLINE fallback rejasini
ishlatadi — testlar internet/API'siz deterministik o'tadi.
"""
import pytest

pytestmark = pytest.mark.asyncio

_PPTX_MEDIA = (
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
)


async def test_generate_returns_download_url(client):
    resp = await client.post(
        "/api/v1/slides/generate",
        json={"prompt": "Quyosh energiyasi haqida taqdimot"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["file_id"]
    assert body["title"]
    assert body["slide_count"] >= 2
    assert body["download_url"] == f"/api/v1/slides/download/{body['file_id']}"


async def test_download_returns_pptx_bytes(client):
    gen = await client.post(
        "/api/v1/slides/generate", json={"prompt": "Sun'iy intellekt asoslari"}
    )
    url = gen.json()["download_url"]

    resp = await client.get(url)
    assert resp.status_code == 200, resp.text
    assert resp.headers["content-type"] == _PPTX_MEDIA
    # .pptx — ZIP konteyner, "PK" sehrli baytlar bilan boshlanadi.
    assert resp.content[:2] == b"PK"
    assert len(resp.content) > 1000


async def test_generate_empty_prompt_422(client):
    resp = await client.post("/api/v1/slides/generate", json={"prompt": "   "})
    assert resp.status_code == 422


async def test_download_invalid_file_id_404(client):
    resp = await client.get("/api/v1/slides/download/not-a-uuid")
    assert resp.status_code == 404


async def test_download_missing_file_404(client):
    # To'g'ri formatdagi, lekin yaratilmagan UUID.
    resp = await client.get(
        "/api/v1/slides/download/00000000-0000-4000-8000-000000000000"
    )
    assert resp.status_code == 404
