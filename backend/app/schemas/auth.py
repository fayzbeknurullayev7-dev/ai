import re
from pydantic import BaseModel, Field, field_validator

# Oddiy, amaliy email regex (email-validator paketiga bog'liq bo'lmaslik uchun —
# loyiha nol-qattiq-bog'liqlik falsafasiga sodiq).
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class _EmailMixin(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def _validate_email(cls, v: str) -> str:
        v = v.strip().lower()
        if not _EMAIL_RE.match(v):
            raise ValueError("email formati noto'g'ri")
        return v


class RegisterRequest(_EmailMixin):
    password: str = Field(min_length=6, max_length=128)
    full_name: str = ""


class LoginRequest(_EmailMixin):
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class UserResponse(BaseModel):
    id: str
    email: str
    full_name: str = ""


class AuthResponse(BaseModel):
    """Register/login javobi — token + foydalanuvchi ma'lumoti birga."""

    user: UserResponse
    token: TokenResponse
