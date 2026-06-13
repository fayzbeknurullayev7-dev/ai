"""SSE oqim javobini parse qilish uchun yordamchi."""
import json
from typing import Any, Dict, List


def parse_sse(text: str) -> List[Dict[str, Any]]:
    """
    `data: {...}` qatorlaridan iborat SSE javob matnini event diktlari
    ro'yxatiga aylantiradi. `[DONE]` sentinel'ini e'tiborsiz qoldiradi.
    """
    events: List[Dict[str, Any]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("data:"):
            continue
        payload = line[len("data:"):].strip()
        if payload == "[DONE]":
            continue
        events.append(json.loads(payload))
    return events


def sse_has_done(text: str) -> bool:
    return any(l.strip() == "data: [DONE]" for l in text.splitlines())
