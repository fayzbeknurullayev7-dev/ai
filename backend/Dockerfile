# syntax=docker/dockerfile:1

# ============================================================================
# Nexus AI Agent — Backend (FastAPI) production image.
# Ko'p bosqichli (multi-stage): builder bog'liqliklarni wheel'larga yig'adi,
# yakuniy image faqat runtime'ni o'z ichiga oladi (kichik va xavfsiz).
# ============================================================================

# ---- 1-bosqich: bog'liqliklarni qurish -------------------------------------
FROM python:3.11-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# Avval faqat requirements — Docker qatlam keshini samarali ishlatamiz.
COPY requirements.txt .
RUN pip wheel --wheel-dir /wheels -r requirements.txt


# ---- 2-bosqich: runtime ----------------------------------------------------
FROM python:3.11-slim AS runtime

# Bufferlanmagan loglar + .pyc yozmaslik (konteyner uchun toza).
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_ENV=production \
    PORT=8000

# curl — healthcheck uchun.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Root bo'lmagan foydalanuvchi (xavfsizlik).
RUN useradd --create-home --uid 1000 appuser

WORKDIR /app

# Builder bosqichidagi tayyor wheel'lardan o'rnatamiz (tarmoqqa chiqmasdan).
COPY --from=builder /wheels /wheels
COPY requirements.txt .
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt \
    && rm -rf /wheels

# Ilova kodi.
COPY . .

USER appuser

EXPOSE 8000

# Konteyner sog'lig'i — orkestrator (compose/k8s) shu orqali holatni biladi.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -fsS http://localhost:8000/health || exit 1

# Gunicorn + Uvicorn worker'lari (production ASGI). Worker soni env orqali.
CMD ["sh", "-c", "gunicorn main:app \
    --workers ${WEB_CONCURRENCY:-2} \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000 \
    --timeout 120 \
    --graceful-timeout 30 \
    --access-logfile - \
    --error-logfile -"]
