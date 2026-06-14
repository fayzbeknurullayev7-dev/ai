from fastapi import APIRouter
from app.api.v1.endpoints import chat, health, agent, rag, auth, slides, video

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(chat.router, prefix="/chat", tags=["Chat"])
api_router.include_router(agent.router, prefix="/agent", tags=["Agent"])
api_router.include_router(rag.router, prefix="/rag", tags=["RAG"])
api_router.include_router(slides.router, prefix="/slides", tags=["Slides"])
api_router.include_router(video.router, prefix="/video", tags=["Video"])
api_router.include_router(health.router, prefix="/health", tags=["Health"])
