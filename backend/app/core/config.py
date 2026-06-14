from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    GROQ_API_KEY: str = ""
    GEMINI_API_KEY: str = ""
    # Kling AI (video generatsiya) — kuniga 66 bepul kredit. Bo'sh bo'lsa
    # /video/generate "Kling API key kerak" deb 503 qaytaradi (UI tayyor turadi).
    KLING_API_KEY: str = ""
    REDIS_URL: str = "redis://localhost:6379"
    APP_ENV: str = "development"
    # Xotira backendi: "memory" (RAM, standart) yoki "redis" (persistent).
    # Production'da docker-compose buni "redis" qilib o'rnatadi.
    MEMORY_BACKEND: str = "memory"
    # web_search uchun ixtiyoriy — o'rnatilsa Tavily, aks holda DuckDuckGo (keysiz).
    TAVILY_API_KEY: str = ""
    # JWT autentifikatsiya. Production'da JWT_SECRET ni ALBATTA o'zgartiring
    # (.env orqali kuchli tasodifiy qiymat bering).
    JWT_SECRET: str = "dev-insecure-secret-change-me"
    JWT_EXPIRES_IN: int = 3600 * 24  # 24 soat (sekundlarda)

    class Config:
        env_file = ".env"


settings = Settings()
