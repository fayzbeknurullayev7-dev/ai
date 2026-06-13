# Nexus AI Agent — Deploy (Docker + server)

Production stack: **FastAPI (gunicorn)** + **Redis** (xotira) + **nginx** (reverse proxy, SSE-aware).

```
Internet ──▶ nginx :80 ──▶ backend :8000 (gunicorn + uvicorn workerlari)
                                │
                                └──▶ redis :6379 (suhbat xotirasi, faktlar)
```

---

## 1. Tez ishga tushirish (local yoki server)

```bash
# 1) Maxfiy kalitlarni sozlang
cp backend/.env.example backend/.env
nano backend/.env          # GROQ_API_KEY, GEMINI_API_KEY ni to'ldiring

# 2) Stack'ni quring va ishga tushiring
docker compose up -d --build

# 3) Tekshirish
curl http://localhost/health
#   → {"status":"ok","service":"nexus-ai-agent"}
curl http://localhost/api/v1/agent/tools
```

To'xtatish / loglar:
```bash
docker compose logs -f backend     # backend loglari
docker compose ps                  # holat + healthcheck
docker compose down                # to'xtatish (redis_data volume saqlanadi)
docker compose down -v             # hamma narsani o'chirish (xotira ham)
```

---

## 2. Muhit o'zgaruvchilari (`backend/.env`)

| O'zgaruvchi | Majburiy | Izoh |
|-------------|:---:|------|
| `GROQ_API_KEY` | ✅ | CoderAgent / PlannerAgent (Groq llama3) |
| `GEMINI_API_KEY` | ⬜ | MediaAgent + RAG semantik embeddinglar. Bo'sh bo'lsa RAG offline `HashingEmbedder` ishlatadi |
| `MEMORY_BACKEND` | ⬜ | compose `redis` qiladi. Lokal'da `memory` (RAM) |
| `REDIS_URL` | ⬜ | compose `redis://redis:6379` qiladi |
| `TAVILY_API_KEY` | ⬜ | web_search uchun; bo'sh bo'lsa DuckDuckGo (keysiz) |

`docker-compose.yml` darajasidagi tashqi o'zgaruvchilar (ixtiyoriy):
- `HTTP_PORT` — nginx tashqi porti (standart `80`).
- `WEB_CONCURRENCY` — gunicorn worker soni (standart `2`; `2 × CPU + 1` tavsiya).

---

## 3. Server'ga o'rnatish (Ubuntu 22.04 misoli)

```bash
# Docker Engine + Compose plugin
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER && newgrp docker

# Loyihani olib kelish
git clone <repo-url> nexus && cd nexus/nexus-ai-agent
cp backend/.env.example backend/.env && nano backend/.env

# Ishga tushirish
docker compose up -d --build
```

Stack `restart: unless-stopped` bilan ishlaydi — server qayta yuklansa avtomatik ko'tariladi.

---

## 4. HTTPS (production, domen bilan)

`deploy/nginx.conf` 80-portda ishlaydi. TLS uchun ikki yo'l:

**A) Tashqi proxy (tavsiya):** Caddy yoki Cloudflare Tunnel'ni nginx oldiga qo'ying — sertifikatni o'sha boshqaradi.

**B) Certbot:** host'da `certbot` bilan sertifikat oling, `deploy/` ga ulang va nginx'ga `443 ssl` server bloki qo'shing (`ssl_certificate` + `ssl_certificate_key`). SSE `location` bloklari o'zgarmaydi.

---

## 5. SSE (real-vaqt oqim) haqida muhim eslatma

`/api/v1/chat/stream` va `/api/v1/agent/stream` — Server-Sent Events. nginx'da
ushbu yo'llar uchun **bufferlash o'chirilgan** (`proxy_buffering off`,
`X-Accel-Buffering: no`, `proxy_read_timeout 3600s`). Boshqa reverse proxy
qo'shsangiz, shu sozlamalarni saqlang — aks holda token'lar real vaqtda emas,
oqim oxirida bir martada kelади.

---

## 6. Flutter klientini ulash

`flutter/lib/core/constants/api_constants.dart` ichida `baseUrl` ni server
manziliga moslang:

```dart
// Production:
static const baseUrl = 'https://api.sizning-domen.uz/api/v1';
// yoki IP:  'http://<server-ip>/api/v1'
```

---

## 7. Sog'liqni tekshirish (monitoring)

- Backend: `GET /health` → `{"status":"ok"}` (Docker HEALTHCHECK shuni ishlatadi).
- `docker compose ps` — har bir servisning `healthy` holati ko'rinadi.
- Redis: `docker compose exec redis redis-cli ping` → `PONG`.

---

## 8. Image'ni alohida qurish (compose'siz)

```bash
cd backend
docker build -t nexus-ai-backend:latest .
docker run -d -p 8000:8000 --env-file .env nexus-ai-backend:latest
```
