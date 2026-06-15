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

    # ---- Telegram admin bot -------------------------------------------------
    # Bot token (Render env: TELEGRAM_BOT_TOKEN). Bo'sh bo'lsa bot o'chiq turadi.
    TELEGRAM_BOT_TOKEN: str = ""
    # Admin chat ID'lar — faqat shu ID'lardan kelgan buyruqlar bajariladi.
    # Vergul bilan ajratilgan ro'yxat, masalan: "7881780111,1248727835".
    TELEGRAM_ADMIN_IDS: str = ""
    # Ixtiyoriy: Telegram webhook secret token (X-Telegram-Bot-Api-Secret-Token
    # sarlavhasi orqali tekshiriladi). Soxta so'rovlardan himoya.
    TELEGRAM_WEBHOOK_SECRET: str = ""
    # Ixtiyoriy: ilova ishga tushganda webhook'ni shu URL'ga o'rnatadi,
    # masalan "https://<render-app>.onrender.com". Bo'sh bo'lsa qo'lda o'rnatiladi.
    TELEGRAM_WEBHOOK_URL: str = ""

    @property
    def telegram_admin_ids(self) -> set[int]:
        """TELEGRAM_ADMIN_IDS satridan int chat ID'lar to'plamini quradi."""
        ids: set[int] = set()
        for part in self.TELEGRAM_ADMIN_IDS.split(","):
            part = part.strip()
            if part:
                try:
                    ids.add(int(part))
                except ValueError:
                    continue
        return ids

    class Config:
        env_file = ".env"


settings = Settings()
