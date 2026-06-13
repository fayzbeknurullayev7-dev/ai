from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.router import api_router
from app.core.config import settings

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


@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "nexus-ai-agent"}
