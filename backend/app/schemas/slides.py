from pydantic import BaseModel
from typing import List

from app.schemas.chat import Message


class SlideRequest(BaseModel):
    prompt: str
    history: List[Message] = []


class SlideGenerateResponse(BaseModel):
    file_id: str
    title: str
    slide_count: int
    download_url: str
