# Nexus AI Agent — Architecture

## Overview

Nexus AI Agent is a mobile-first AI chat platform with an intelligent agent
routing system. The user sends a message, the backend classifies it, and
routes it to the most suitable AI provider.

```
Flutter App
    │
    │  HTTP (REST / SSE Stream)
    ▼
FastAPI Backend
    │
    ├── AgentRouter (keyword classifier)
    │       │
    │       ├── CoderAgent ──► Groq API (llama-3.3-70b-versatile)
    │       │                   Fast code generation & debugging
    │       │
    │       └── MediaAgent ──► Gemini API (gemini-1.5-flash)
                                Multimodal: image, creative, design
```

## Routing Logic

```
User message
    │
    ▼
AgentRouter._select_agent(message)
    │
    ├── Tokenize message (word boundaries, not substring)
    ├── Count CODE keywords  (python, dart, bug, fix, class, function...)
    ├── Count MEDIA keywords (rasm, image, dizayn, color, logo...)
    │
    ├── media_score > code_score  →  MediaAgent (Gemini)
    └── default / code_score ≥ media_score  →  CoderAgent (Groq)
```

## Clean Architecture Layers

### Backend
```
app/
├── api/          ← Presentation layer (FastAPI endpoints, HTTP contracts)
├── agents/       ← Domain + Infrastructure (business logic + AI providers)
├── schemas/      ← Data Transfer Objects (Pydantic models)
└── core/         ← Config, DI, cross-cutting concerns
```

### Flutter
```
features/chat/
├── presentation/ ← UI (pages, widgets, Riverpod providers)
├── domain/       ← Entities, Repository interfaces, Use Cases
└── data/         ← Repository implementations, API models, Hive storage
```

## SOLID Principles Applied

| Principle | Implementation |
|-----------|---------------|
| **S** — Single Responsibility | CoderAgent handles only code; MediaAgent only media |
| **O** — Open/Closed | New agents extend BaseAgent without modifying AgentRouter |
| **L** — Liskov Substitution | AgentRouter works with any BaseAgent subclass |
| **I** — Interface Segregation | BaseAgent exposes only `process` and `stream` |
| **D** — Dependency Inversion | AgentRouter depends on BaseAgent abstraction, not concrete classes |

## Data Flow

1. Flutter `ChatNotifier.sendMessage(text)` →
2. `ChatRepositoryImpl.sendMessage(...)` → POST `/api/v1/chat/` →
3. FastAPI `chat` endpoint → `AgentRouter.route(message, history)` →
4. Selected Agent processes via Groq/Gemini API →
5. `AgentResult` returned → JSON response →
6. Flutter `ChatMessageModel.fromJson(...)` →
7. `ChatState` updated → UI re-rendered via Riverpod

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile UI | Flutter 3.x, Riverpod, GoRouter, flutter_markdown |
| HTTP Client | Dio |
| Backend | FastAPI, Python 3.11+ |
| Code AI | Groq Cloud (llama-3.3-70b-versatile) |
| Media AI | Google Gemini (gemini-1.5-flash) |
| Caching | Redis (optional, for session persistence) |
| Streaming | Server-Sent Events (SSE) |
