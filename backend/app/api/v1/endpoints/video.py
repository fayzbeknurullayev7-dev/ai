"""Video generatsiya endpointi (Kling AI).

Kling AI kuniga 66 bepul kredit beradi. Hozircha API key sozlanmagan —
`KLING_API_KEY` bo'sh bo'lsa endpoint **503** bilan "Kling API key kerak"
xabarini qaytaradi (Flutter UI shu xabarni ko'rsatadi). Key qo'shilgach,
shu yerga Kling chaqiruvi qo'shiladi.
"""
from fastapi import APIRouter, HTTPException

from app.core.config import settings
from app.schemas.video import VideoGenerateResponse, VideoRequest

router = APIRouter()

_KEY_REQUIRED = (
    "Kling API key kerak. Video yaratish uchun sozlamalarga Kling AI kalitini "
    "qo'shing (kuniga 66 bepul kredit)."
)


@router.post("/generate", response_model=VideoGenerateResponse)
async def generate_video(request: VideoRequest) -> VideoGenerateResponse:
    prompt = (request.prompt or "").strip()
    if not prompt:
        raise HTTPException(status_code=422, detail="Prompt bo'sh bo'lmasligi kerak")

    if not settings.KLING_API_KEY:
        # 503 — xizmat hozircha mavjud emas (key sozlanmagan).
        raise HTTPException(status_code=503, detail=_KEY_REQUIRED)

    # TODO: Kling AI API chaqiruvi (key qo'shilgach).
    raise HTTPException(status_code=503, detail=_KEY_REQUIRED)
