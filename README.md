# Nexus AI Agent

Multi-agent AI chat platforma: **Groq** (kod) + **Gemini** (media), FastAPI backend va Flutter frontend.

## Struktura

```
nexus-ai-agent/
├── backend/          # FastAPI + agent routing
│   └── app/
│       ├── api/      # HTTP endpointlar
│       ├── agents/   # CoderAgent, MediaAgent, AgentRouter
│       ├── schemas/  # Pydantic modellar
│       └── core/     # config, DI
├── flutter/          # Flutter mobil ilova (Clean Architecture)
└── architecture.md   # to'liq arxitektura hujjati
```

## Ishga tushirish

### Backend
```bash
cd backend
cp .env.example .env          # API kalitlarni .env ga yozing
pip install -r requirements.txt --break-system-packages
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
API: `http://localhost:8000` · Docs: `http://localhost:8000/docs`

### Flutter
```bash
cd flutter
flutter pub get
flutter run
```
> Android emulyator backendga `http://10.0.2.2:8000` orqali ulanadi
> (`lib/core/constants/api_constants.dart`). iOS/Web uchun `localhost` ni yoqing.

## Tuzatilgan buglar (spec'dagi xatolar)

Bu kod `CLAUDE.md` spetsifikatsiyasi asosida yaratilgan, lekin quyidagi
xatolar ishga tushirishdan oldin tuzatildi:

| # | Fayl | Bug | Yechim |
|---|------|-----|--------|
| 1 | `data/models/chat_message_model.dart` | `fromJson` backend qaytarmaydigan `json['id']` ni o'qib crash qilardi | id klientda `Uuid().v4()` bilan generatsiya qilinadi |
| 2 | `presentation/providers/chat_provider.dart` | History filtri `!state.isLoading` tufayli doim bo'sh edi → AI kontekstni eslamasdi | Yangi xabardan oldingi snapshot history sifatida yuboriladi |
| 3 | `core/network/dio_client.dart` | `debugPrint` ishlatilgan, lekin import yo'q → compile error | `package:flutter/foundation.dart` qo'shildi, log faqat debug rejimda |
| 4 | `agents/coder_agent.py` | `llama3-70b-8192` Groq'da decommission qilingan | `llama-3.3-70b-versatile` ga almashtirildi |
| 5 | `main.py` (backend) | `allow_origins=["*"]` + `allow_credentials=True` — CORS spec taqiqlaydi | `allow_credentials=False` |
| 7 | `agents/router.py` | Substring match (`"kod"`→"dekoder") soxta routing | Tokenizatsiya (so'z chegarasi) bo'yicha aniq moslik |
| 9 | `data/repositories/chat_repository_impl.dart` | Ishlatilmaydigan `_uuid` maydoni | Olib tashlandi |

## Tech Stack

Flutter · Riverpod · GoRouter · Dio · FastAPI · Groq · Gemini · Redis (ixtiyoriy)

Batafsil: [`architecture.md`](./architecture.md)
