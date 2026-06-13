"""
/api/v1/auth endpointlari integratsiya testlari.

Toza InMemoryUserStore conftest orqali injeksiya qilinadi (har test izolyatsiya).
"""
import pytest

pytestmark = pytest.mark.asyncio

_USER = {"email": "aziz@example.com", "password": "secret123", "full_name": "Aziz"}


async def _register(client, **over):
    data = {**_USER, **over}
    return await client.post("/api/v1/auth/register", json=data)


# ---- Register ------------------------------------------------------------- #
async def test_register_success(client):
    resp = await _register(client)
    assert resp.status_code == 201
    body = resp.json()
    assert body["user"]["email"] == "aziz@example.com"
    assert body["user"]["full_name"] == "Aziz"
    assert "id" in body["user"]
    assert body["token"]["access_token"]
    assert body["token"]["token_type"] == "bearer"
    # Parol hech qachon qaytmasligi kerak
    assert "password" not in body["user"]
    assert "password_hash" not in str(body)


async def test_register_duplicate_email_409(client):
    await _register(client)
    resp = await _register(client)
    assert resp.status_code == 409


async def test_register_email_normalized(client):
    """Email katta harf/probel bilan kelса ham normallashtiriladi."""
    r1 = await _register(client, email="  Aziz@Example.COM  ")
    assert r1.status_code == 201
    assert r1.json()["user"]["email"] == "aziz@example.com"
    # Endi shu email kichik harfda dublikat hisoblanadi
    r2 = await _register(client, email="aziz@example.com")
    assert r2.status_code == 409


async def test_register_invalid_email_422(client):
    resp = await _register(client, email="notanemail")
    assert resp.status_code == 422


async def test_register_short_password_422(client):
    resp = await _register(client, password="123")
    assert resp.status_code == 422


# ---- Login ---------------------------------------------------------------- #
async def test_login_success(client):
    await _register(client)
    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": "aziz@example.com", "password": "secret123"},
    )
    assert resp.status_code == 200
    assert resp.json()["token"]["access_token"]


async def test_login_wrong_password_401(client):
    await _register(client)
    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": "aziz@example.com", "password": "wrong"},
    )
    assert resp.status_code == 401


async def test_login_unknown_user_401(client):
    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": "yoq@example.com", "password": "secret123"},
    )
    assert resp.status_code == 401


# ---- /me (protected) ------------------------------------------------------ #
async def test_me_with_valid_token(client):
    reg = await _register(client)
    token = reg.json()["token"]["access_token"]
    resp = await client.get(
        "/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"}
    )
    assert resp.status_code == 200
    assert resp.json()["email"] == "aziz@example.com"


async def test_me_without_token_401(client):
    resp = await client.get("/api/v1/auth/me")
    assert resp.status_code == 401


async def test_me_invalid_token_401(client):
    resp = await client.get(
        "/api/v1/auth/me", headers={"Authorization": "Bearer garbage.token.here"}
    )
    assert resp.status_code == 401


async def test_me_malformed_header_401(client):
    resp = await client.get(
        "/api/v1/auth/me", headers={"Authorization": "Token abc"}
    )
    assert resp.status_code == 401


async def test_login_token_works_for_me(client):
    """Login orqali olingan token ham /me da ishlaydi (register'dan mustaqil)."""
    await _register(client)
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "aziz@example.com", "password": "secret123"},
    )
    token = login.json()["token"]["access_token"]
    me = await client.get(
        "/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"}
    )
    assert me.status_code == 200
    assert me.json()["full_name"] == "Aziz"


async def test_user_isolation_between_tests(client):
    """Har test toza user store oladi — oldingi foydalanuvchilar yo'q."""
    resp = await client.post(
        "/api/v1/auth/login",
        json={"email": "aziz@example.com", "password": "secret123"},
    )
    assert resp.status_code == 401  # hech kim ro'yxatdan o'tmagan
