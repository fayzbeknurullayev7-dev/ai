from pydantic import BaseModel
from typing import Optional


class VideoRequest(BaseModel):
    prompt: str


class VideoGenerateResponse(BaseModel):
    status: str  # "ok" | "key_required"
    detail: str
    video_url: Optional[str] = None
