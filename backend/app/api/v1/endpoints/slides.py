"""Slayd (.pptx) generatsiya endpointlari.

  POST /slides/generate        → promptdan .pptx yaratadi, download_url qaytaradi
  GET  /slides/download/{id}   → tayyor .pptx faylni yuklab beradi (FileResponse)

Endpointlar PUBLIC (auth talab qilmaydi): yuklab olish brauzerda ochilgani
uchun Bearer token yubora olmaydi — `file_id` (UUID) o'zi yetarli "kalit".
"""
import uuid
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from app.schemas.slides import SlideGenerateResponse, SlideRequest
from app.slides import build_pptx, generate_outline

router = APIRouter()

# <backend>/generated_slides/ — yaratilgan fayllar shu yerda saqlanadi.
_OUTPUT_DIR = Path(__file__).resolve().parents[4] / "generated_slides"
_PPTX_MEDIA = (
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
)


def _safe_path(file_id: str) -> Path:
    """`file_id` ni UUID sifatida tekshiradi (path-traversal himoyasi)."""
    try:
        uuid.UUID(file_id)
    except (ValueError, AttributeError):
        raise HTTPException(status_code=404, detail="Fayl topilmadi")
    return _OUTPUT_DIR / f"{file_id}.pptx"


@router.post("/generate", response_model=SlideGenerateResponse)
async def generate_slides(request: SlideRequest) -> SlideGenerateResponse:
    prompt = (request.prompt or "").strip()
    if not prompt:
        raise HTTPException(status_code=422, detail="Prompt bo'sh bo'lmasligi kerak")
    try:
        deck = await generate_outline(prompt)
        data = build_pptx(deck)
    except Exception as e:  # pragma: no cover - kutilmagan generatsiya xatosi
        raise HTTPException(status_code=500, detail=f"Slayd yaratilmadi: {e}")

    file_id = str(uuid.uuid4())
    _OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    (_OUTPUT_DIR / f"{file_id}.pptx").write_bytes(data)

    return SlideGenerateResponse(
        file_id=file_id,
        title=deck.title,
        slide_count=deck.slide_count,
        download_url=f"/api/v1/slides/download/{file_id}",
    )


@router.get("/download/{file_id}")
async def download_slides(file_id: str) -> FileResponse:
    path = _safe_path(file_id)
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Fayl topilmadi")
    return FileResponse(
        path,
        media_type=_PPTX_MEDIA,
        filename="nexus-taqdimot.pptx",
    )
