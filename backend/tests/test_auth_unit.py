"""
Auth xavfsizligi uchun offline unit testlar — parol hash + JWT (stdlib).
"""
import pytest

from app.auth.security import (
    hash_password,
    verify_password,
    create_access_token,
    decode_access_token,
    TokenError,
)

pytestmark = pytest.mark.asyncio


# ---- Parol hashlash ------------------------------------------------------- #
async def test_password_hash_and_verify():
    h = hash_password("MyP@ssw0rd")
    assert h.startswith("pbkdf2_sha256$")
    assert verify_password("MyP@ssw0rd", h) is True
    assert verify_password("noto'g'ri", h) is False


async def test_password_hash_is_salted():
    """Bir xil parol har safar boshqa hash beradi (tasodifiy salt)."""
    assert hash_password("salom") != hash_password("salom")


async def test_verify_rejects_garbage():
    assert verify_password("x", "buzilgan-hash") is False
    assert verify_password("x", "") is False


async def test_empty_password_rejected():
    with pytest.raises(ValueError):
        hash_password("")


# ---- JWT ------------------------------------------------------------------ #
async def test_jwt_roundtrip():
    token = create_access_token("user-1", "secret", expires_in=3600, now=1000)
    payload = decode_access_token(token, "secret", now=1001)
    assert payload["sub"] == "user-1"
    assert payload["iat"] == 1000
    assert payload["exp"] == 4600


async def test_jwt_extra_claims():
    token = create_access_token(
        "u1", "secret", extra={"email": "a@b.com"}, now=0
    )
    payload = decode_access_token(token, "secret", now=1)
    assert payload["email"] == "a@b.com"


async def test_jwt_wrong_secret_fails():
    token = create_access_token("u1", "secret", now=0)
    with pytest.raises(TokenError):
        decode_access_token(token, "boshqa-secret", now=1)


async def test_jwt_expired():
    token = create_access_token("u1", "secret", expires_in=100, now=1000)
    with pytest.raises(TokenError):
        decode_access_token(token, "secret", now=1101)  # exp = 1100


async def test_jwt_tampered_payload():
    token = create_access_token("u1", "secret", now=0)
    seg_h, seg_p, seg_s = token.split(".")
    tampered = f"{seg_h}.{seg_p}x.{seg_s}"
    with pytest.raises(TokenError):
        decode_access_token(tampered, "secret", now=1)


async def test_jwt_malformed():
    with pytest.raises(TokenError):
        decode_access_token("not-a-jwt", "secret")
