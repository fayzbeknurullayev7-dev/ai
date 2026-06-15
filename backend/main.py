from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.router import api_router
from app.core.config import settings
from app.core.error_log import install_error_log_handler
from app.telegram_bot import setup_telegram

# Xato loglari halqa-buferi (Telegram /logs uchun) — import vaqtida o'rnatiladi.
install_error_log_handler()

app = FastAPI(
    title="Nexus AI Agent API",
    version="1.0.0",
    description="Multi-agent AI platform: Groq (code) + Gemini (media)",
)

# FIX (#5): allow_credentials=True bilan allow_origins=["*"] kombinatsiyasi
# CORS spec bo'yicha taqiqlangan (brauzer rad etadi). Credentials kerak emas,
# shuning uchun False qildik. Agar cookie/auth kerak bo'lsa, aniq origin yozing.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")

# Telegram admin bot — webhook router + startup/shutdown hodisalari.
setup_telegram(app)


@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "nexus-ai-agent"}
