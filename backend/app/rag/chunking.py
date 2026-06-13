"""
Matnni bo'laklarga (chunk) ajratish — RAG indekslashning birinchi qadami.

Strategiya: avval paragraflarga (bo'sh qatorlar) bo'lamiz, so'ng har bir
paragrafni belgilangan belgi byudjetiga (`chunk_size`) sig'diramiz. Uzun
paragraflar so'z chegarasi bo'yicha kesiladi va `overlap` belgicha qism
keyingi bo'lakka takrorlanadi (kontekst yo'qolmasligi uchun).
"""
from __future__ import annotations

import re
from typing import List

_WHITESPACE_RE = re.compile(r"\s+")


def _normalize(text: str) -> str:
    return _WHITESPACE_RE.sub(" ", text).strip()


def split_text(text: str, chunk_size: int = 512, overlap: int = 64) -> List[str]:
    """
    Matnni ~`chunk_size` belgilik, `overlap` belgilik ustma-ustlikli bo'laklarga
    ajratadi. Bo'sh natija bo'lsa bo'sh ro'yxat qaytadi.
    """
    if chunk_size <= 0:
        raise ValueError("chunk_size musbat bo'lishi kerak")
    if overlap < 0 or overlap >= chunk_size:
        raise ValueError("overlap 0 <= overlap < chunk_size bo'lishi kerak")

    paragraphs = [p for p in re.split(r"\n\s*\n", text) if _normalize(p)]
    chunks: List[str] = []

    for para in paragraphs:
        para = _normalize(para)
        if len(para) <= chunk_size:
            chunks.append(para)
            continue
        # Uzun paragrafni so'z chegarasi bo'yicha ustma-ust bo'laklarga kesamiz.
        words = para.split(" ")
        current = ""
        for word in words:
            candidate = word if not current else f"{current} {word}"
            if len(candidate) > chunk_size and current:
                chunks.append(current)
                # overlap: oxirgi belgilarni keyingi bo'lak boshiga olib o'tamiz.
                tail = current[-overlap:] if overlap else ""
                current = f"{tail} {word}".strip() if tail else word
            else:
                current = candidate
        if current:
            chunks.append(current)

    return chunks
