import time

from fastapi import APIRouter, Depends, HTTPException

from app.core.config import settings
from app.core.dependencies import get_user_store, get_current_user
from app.auth import (
    hash_password,
    verify_password,
    create_access_token,
    EmailAlreadyExists,
    BaseUserStore,
    User,
)
from app.schemas.auth import (
    RegisterRequest,
    LoginRequest,
    AuthResponse,
    UserResponse,
    TokenResponse,
)

router = APIRouter()


def _issue_token(user: User) -> TokenResponse:
    token = create_access_token(
        subject=user.id,
        secret=settings.JWT_SECRET,
        expires_in=settings.JWT_EXPIRES_IN,
        extra={"email": user.email},
    )
    return TokenResponse(access_token=token, expires_in=settings.JWT_EXPIRES_IN)


def _auth_response(user: User) -> AuthResponse:
    return AuthResponse(
        user=UserResponse(id=user.id, email=user.email, full_name=user.full_name),
        token=_issue_token(user),
    )


@router.post("/register", response_model=AuthResponse, status_code=201)
async def register(
    request: RegisterRequest,
    store: BaseUserStore = Depends(get_user_store),
):
    """Yangi foydalanuvchi ro'yxatdan o'tkazadi va darhol token beradi."""
    try:
        user = await store.create(
            email=request.email,
            password_hash=hash_password(request.password),
            full_name=request.full_name,
            created_at=time.time(),
        )
    except EmailAlreadyExists:
        raise HTTPException(
            status_code=409, detail="Bu email allaqachon ro'yxatdan o'tgan"
        )
    return _auth_response(user)


@router.post("/login", response_model=AuthResponse)
async def login(
    request: LoginRequest,
    store: BaseUserStore = Depends(get_user_store),
):
    """Email + parol bilan kirish — to'g'ri bo'lsa token qaytaradi."""
    user = await store.get_by_email(request.email)
    # Foydalanuvchi yo'q yoki parol noto'g'ri — bir xil xabar (enumeration'dan saqlash).
    if user is None or not verify_password(request.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email yoki parol noto'g'ri")
    return _auth_response(user)


@router.get("/me", response_model=UserResponse)
async def me(current: User = Depends(get_current_user)):
    """Joriy (token bo'yicha) foydalanuvchi ma'lumotlari."""
    return UserResponse(
        id=current.id, email=current.email, full_name=current.full_name
    )
