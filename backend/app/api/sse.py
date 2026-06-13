import json
from typing import Any, AsyncIterator, Dict
from fastapi.responses import StreamingResponse

# nginx kabi proxylarda bufferlashni o'chiradi (real vaqt oqim uchun).
_SSE_HEADERS = {
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
    "X-Accel-Buffering": "no",
}


def sse_response(events: AsyncIterator[Dict[str, Any]]) -> StreamingResponse:
    """
    Event diktlari oqimini Server-Sent Events javobiga aylantiradi.

    Har bir event:  `data: {json}\\n\\n`
    Oxirida:        `data: [DONE]\\n\\n`
    Xato yuz bersa, oqim ichida `{"type":"error",...}` yuboriladi.
    """

    async def generator():
        try:
            async for ev in events:
                yield f"data: {json.dumps(ev, ensure_ascii=False)}\n\n"
        except Exception as e:  # oqim ichidagi xatoni ham mijozga yetkazamiz
            err = {"type": "error", "detail": f"{type(e).__name__}: {e}"}
            yield f"data: {json.dumps(err, ensure_ascii=False)}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(
        generator(), media_type="text/event-stream", headers=_SSE_HEADERS
    )
