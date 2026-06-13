"""
Autentifikatsiya xavfsizligi — parol hashlash va JWT (stdlib-only).

Loyiha falsafasi (HashingEmbedder / DuckDuckGo bilan bir xil): tashqi qattiq
bog'liqliksiz, deterministik va offline test qilinadigan. Parol uchun
`hashlib.pbkdf2_hmac` (salt + iteratsiyalar), token uchun qo'lda HS256 JWT
(`hmac` + `base64url`). Bu passlib/python-jose talab qilmaydi.

Eslatma: jiddiy production'da argon2/bcrypt va tekshirilgan JWT kutubxonasi
afzal — bu modul interfeysi shu yo'nalishda almashtirishga tayyor (faqat shu
fayl o'zgaradi).
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time
from typing import Any, Dict, Optional

# --- Parol hashlash (PBKDF2-HMAC-SHA256) -------------------------------------
_PBKDF2_ALGO = "sha256"
_PBKDF2_ITERATIONS = 200_000
_SALT_BYTES = 16


def hash_password(password: str) -> str:
    """
    Parolni tasodifiy salt bilan hashlaydi.
    Format:  pbkdf2_sha256$<iterations>$<salt_hex>$<hash_hex>
    """
    if not password:
        raise ValueError("parol bo'sh bo'lishi mumkin emas")
    salt = os.urandom(_SALT_BYTES)
    dk = hashlib.pbkdf2_hmac(
        _PBKDF2_ALGO, password.encode("utf-8"), salt, _PBKDF2_ITERATIONS
    )
    return f"pbkdf2_sha256${_PBKDF2_ITERATIONS}${salt.hex()}${dk.hex()}"


def verify_password(password: str, stored: str) -> bool:
    """Parolni saqlangan hash bilan vaqt-bardosh (timing-safe) solishtiradi."""
    try:
        algo, iters_s, salt_hex, hash_hex = stored.split("$")
        if algo != "pbkdf2_sha256":
            return False
        iterations = int(iters_s)
        salt = bytes.fromhex(salt_hex)
        expected = bytes.fromhex(hash_hex)
    except (ValueError, AttributeError):
        return False
    dk = hashlib.pbkdf2_hmac(
        _PBKDF2_ALGO, password.encode("utf-8"), salt, iterations
    )
    return hmac.compare_digest(dk, expected)


# --- JWT (HS256, qo'lda) -----------------------------------------------------
def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


class TokenError(Exception):
    """JWT yaroqsiz, muddati o'tgan yoki imzosi noto'g'ri."""


def create_access_token(
    subject: str,
    secret: str,
    expires_in: int = 3600,
    extra: Optional[Dict[str, Any]] = None,
    *,
    now: Optional[int] = None,
) -> str:
    """
    HS256 JWT yaratadi. `subject` — odatda user id. `now` testlar uchun
    injeksiya qilinadi (deterministiklik).
    """
    issued = int(now if now is not None else time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload: Dict[str, Any] = {
        "sub": subject,
        "iat": issued,
        "exp": issued + expires_in,
    }
    if extra:
        payload.update(extra)

    seg_h = _b64url_encode(json.dumps(header, separators=(",", ":")).encode())
    seg_p = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode())
    signing_input = f"{seg_h}.{seg_p}".encode("ascii")
    sig = hmac.new(secret.encode("utf-8"), signing_input, hashlib.sha256).digest()
    return f"{seg_h}.{seg_p}.{_b64url_encode(sig)}"


def decode_access_token(
    token: str, secret: str, *, now: Optional[int] = None
) -> Dict[str, Any]:
    """
    JWT'ni tekshiradi (imzo + muddat) va payload qaytaradi.
    Xato bo'lsa TokenError ko'taradi.
    """
    try:
        seg_h, seg_p, seg_s = token.split(".")
    except (ValueError, AttributeError):
        raise TokenError("token formati noto'g'ri")

    signing_input = f"{seg_h}.{seg_p}".encode("ascii")
    expected_sig = hmac.new(
        secret.encode("utf-8"), signing_input, hashlib.sha256
    ).digest()
    try:
        actual_sig = _b64url_decode(seg_s)
    except Exception:
        raise TokenError("imzo dekodlanmadi")
    if not hmac.compare_digest(expected_sig, actual_sig):
        raise TokenError("imzo noto'g'ri")

    try:
        payload = json.loads(_b64url_decode(seg_p))
    except Exception:
        raise TokenError("payload dekodlanmadi")

    current = int(now if now is not None else time.time())
    exp = payload.get("exp")
    if exp is not None and current >= int(exp):
        raise TokenError("token muddati o'tgan")

    return payload
