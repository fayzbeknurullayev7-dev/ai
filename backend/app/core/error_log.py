"""Xato loglari uchun yengil halqa-bufer (ring buffer) va logging handler.

Telegram bot `/logs` buyrug'i shu yerdagi oxirgi xatolarni o'qiydi. Hech qanday
tashqi servis yoki fayl shart emas — xotirada (RAM) cheklangan deque saqlanadi.

Foydalanish (main.py'da bir marta):
    from app.core.error_log import install_error_log_handler
    install_error_log_handler()
"""
from __future__ import annotations

import logging
import time
from collections import deque
from dataclasses import dataclass
from typing import Deque, List

# Saqlanadigan xatolar soni (eng yangi N tasi). 200 — /logs uchun yetarli zaxira.
_MAX_RECORDS = 200


@dataclass
class ErrorEntry:
    """Bitta xato yozuvi — Telegram'da ko'rsatish uchun zarur maydonlar."""

    ts: float            # epoch sekund
    level: str           # "ERROR" | "CRITICAL"
    logger: str          # logger nomi
    message: str         # formatlangan xabar (traceback'siz)


class _RingBufferHandler(logging.Handler):
    """ERROR va undan yuqori darajadagi loglarni xotira buferiga yozadi."""

    def __init__(self) -> None:
        super().__init__(level=logging.ERROR)
        self._buf: Deque[ErrorEntry] = deque(maxlen=_MAX_RECORDS)

    def emit(self, record: logging.LogRecord) -> None:
        try:
            msg = record.getMessage()
            # Agar exception bo'lsa, qisqa turdagi xabarni qo'shamiz (to'liq
            # traceback'siz — Telegram xabarini ixcham saqlash uchun).
            if record.exc_info and record.exc_info[1] is not None:
                exc = record.exc_info[1]
                msg = f"{msg} | {type(exc).__name__}: {exc}"
            self._buf.append(
                ErrorEntry(
                    ts=record.created,
                    level=record.levelname,
                    logger=record.name,
                    message=msg,
                )
            )
        except Exception:  # pragma: no cover - logging hech qachon yiqilmasin
            pass

    def recent(self, limit: int = 20) -> List[ErrorEntry]:
        """Eng yangi `limit` ta xatoni (eskidan yangiga) qaytaradi."""
        items = list(self._buf)
        return items[-limit:]


# Yagona global handler (singleton).
_handler = _RingBufferHandler()
_installed = False


def install_error_log_handler() -> None:
    """Root logger'ga halqa-bufer handler'ini bir marta o'rnatadi."""
    global _installed
    if _installed:
        return
    logging.getLogger().addHandler(_handler)
    _installed = True


def get_recent_errors(limit: int = 20) -> List[ErrorEntry]:
    """Oxirgi xatolarni qaytaradi (Telegram `/logs` uchun)."""
    return _handler.recent(limit)


def record_error(message: str, logger: str = "nexus", level: str = "ERROR") -> None:
    """Qo'lda xato qo'shish (handler chetlab o'tilganda foydali)."""
    _handler._buf.append(
        ErrorEntry(ts=time.time(), level=level, logger=logger, message=message)
    )
