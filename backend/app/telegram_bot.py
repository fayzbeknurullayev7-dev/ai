"""Telegram admin bot — faqat httpx (webhook), python-telegram-bot YO'Q.

Render env'da `TELEGRAM_BOT_TOKEN` va `TELEGRAM_ADMIN_IDS` (vergul bilan)
o'rnatiladi. Faqat admin chat ID'laridan kelgan buyruqlar bajariladi.

Buyruqlar:
    /status              — Groq, Gemini, Kling, backend holati (jonli tekshiruv)
    /setkey GROQ <key>   — Groq API key'ni runtime'da yangilash
    /setkey GEMINI <key> — Gemini key
    /setkey KLING <key>  — Kling key
    /logs                — oxirgi 20 ta xato
    /restart             — worker (agent klientlari)ni qayta ishga tushirish
    /limits              — har bir API ning limit holati

Webhook: Telegram POST'ni `/api/v1/telegram/webhook` ga yuboradi. Agar
`TELEGRAM_WEBHOOK_SECRET` o'rnatilgan bo'lsa, `X-Telegram-Bot-Api-Secret-Token`
sarlavhasi tekshiriladi. `TELEGRAM_WEBHOOK_URL` berilsa, ishga tushganda webhook
avtomatik o'rnatiladi.
"""
from __future__ import annotations

import asyncio
import html
import logging
import os
from datetime import datetime, timezone
from typing import Optional

import httpx
from fastapi import APIRouter, FastAPI, Header, Request

from app.core.config import settings
from app.core.error_log import get_recent_errors

logger = logging.getLogger("nexus.telegram")

_TELEGRAM_API = "https://api.telegram.org/bot{token}/{method}"

# Provayderlar uchun key sozlamalari nomi (settings atributi + env nomi).
_PROVIDER_ENV = {
    "GROQ": "GROQ_API_KEY",
    "GEMINI": "GEMINI_API_KEY",
    "KLING": "KLING_API_KEY",
}


def _mask(key: str) -> str:
    """Key'ni loglar/javoblar uchun yashiradi: faqat oxirgi 4 belgi ko'rinadi."""
    key = (key or "").strip()
    if len(key) <= 4:
        return "•" * len(key)
    return "•" * (len(key) - 4) + key[-4:]


def _fmt_ts(ts: float) -> str:
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%m-%d %H:%M:%S")


class TelegramBot:
    """Telegram Bot API bilan httpx orqali ishlaydigan yengil admin bot."""

    def __init__(self) -> None:
        self._client = httpx.AsyncClient(timeout=20.0)

    @property
    def enabled(self) -> bool:
        return bool(settings.TELEGRAM_BOT_TOKEN)

    def _is_admin(self, chat_id: int) -> bool:
        return chat_id in settings.telegram_admin_ids

    # ------------------------------------------------------------------ API --
    async def _call(self, method: str, **payload) -> Optional[dict]:
        if not self.enabled:
            return None
        url = _TELEGRAM_API.format(token=settings.TELEGRAM_BOT_TOKEN, method=method)
        try:
            resp = await self._client.post(url, json=payload)
            return resp.json()
        except Exception as e:  # tarmoq xatosi — bot ishlashda davom etsin
            logger.error("Telegram %s xatosi: %s", method, e)
            return None

    async def send_message(self, chat_id: int, text: str) -> None:
        # Telegram bitta xabar uchun ~4096 belgi cheklovi.
        for part in _chunk(text, 4000):
            await self._call(
                "sendMessage",
                chat_id=chat_id,
                text=part,
                parse_mode="HTML",
                disable_web_page_preview=True,
            )

    async def set_webhook(self, url: str) -> Optional[dict]:
        payload = {"url": url, "allowed_updates": ["message"]}
        if settings.TELEGRAM_WEBHOOK_SECRET:
            payload["secret_token"] = settings.TELEGRAM_WEBHOOK_SECRET
        return await self._call("setWebhook", **payload)

    async def aclose(self) -> None:
        await self._client.aclose()

    # -------------------------------------------------------------- Updates --
    async def handle_update(self, update: dict) -> None:
        message = update.get("message") or update.get("edited_message")
        if not message:
            return
        chat = message.get("chat", {})
        chat_id = chat.get("id")
        text = (message.get("text") or "").strip()
        if chat_id is None or not text:
            return

        if not self._is_admin(chat_id):
            # Ruxsatsiz — sokin rad etish (kim so' raganini loglaymiz).
            logger.warning("Telegram: ruxsatsiz chat_id=%s", chat_id)
            await self.send_message(chat_id, "⛔️ Ruxsat yo'q. Bu bot faqat adminlar uchun.")
            return

        cmd, _, rest = text.partition(" ")
        cmd = cmd.lower().lstrip("/").split("@")[0]  # /status@BotName -> status
        rest = rest.strip()

        handler = {
            "start": self._cmd_help,
            "help": self._cmd_help,
            "status": self._cmd_status,
            "setkey": self._cmd_setkey,
            "logs": self._cmd_logs,
            "restart": self._cmd_restart,
            "limits": self._cmd_limits,
        }.get(cmd)

        if handler is None:
            await self.send_message(
                chat_id, "Noma'lum buyruq. /help bilan ro'yxatni ko'ring."
            )
            return

        try:
            await handler(chat_id, rest)
        except Exception as e:
            logger.error("Telegram buyruq xatosi (%s): %s", cmd, e, exc_info=True)
            await self.send_message(chat_id, f"❌ Xatolik: <code>{html.escape(str(e))}</code>")

    # ------------------------------------------------------------- Commands --
    async def _cmd_help(self, chat_id: int, _: str) -> None:
        await self.send_message(
            chat_id,
            "<b>Nexus AI — Admin bot</b>\n\n"
            "/status — barcha service holati\n"
            "/limits — API limitlari (Groq / Gemini / Kling)\n"
            "/logs — oxirgi 20 ta xato\n"
            "/setkey GROQ &lt;key&gt; — Groq key yangilash\n"
            "/setkey GEMINI &lt;key&gt; — Gemini key yangilash\n"
            "/setkey KLING &lt;key&gt; — Kling key yangilash\n"
            "/restart — worker (agent klientlari)ni qayta ishga tushirish",
        )

    async def _cmd_status(self, chat_id: int, _: str) -> None:
        await self.send_message(chat_id, "⏳ Holat tekshirilmoqda...")
        groq_ok, groq_note = await self._check_groq()
        gem_ok, gem_note = await self._check_gemini()
        kling_ok, kling_note = self._check_kling()

        def mark(ok: Optional[bool]) -> str:
            if ok is True:
                return "🟢"
            if ok is False:
                return "🔴"
            return "🟡"

        lines = [
            "<b>📊 Service holati</b>",
            f"{mark(True)} <b>Backend</b>: ishlamoqda",
            f"{mark(groq_ok)} <b>Groq</b>: {groq_note}",
            f"{mark(gem_ok)} <b>Gemini</b>: {gem_note}",
            f"{mark(kling_ok)} <b>Kling</b>: {kling_note}",
        ]
        await self.send_message(chat_id, "\n".join(lines))

    async def _cmd_setkey(self, chat_id: int, rest: str) -> None:
        parts = rest.split(maxsplit=1)
        if len(parts) < 2:
            await self.send_message(
                chat_id,
                "Foydalanish: <code>/setkey GROQ &lt;key&gt;</code>\n"
                "Provayderlar: GROQ, GEMINI, KLING",
            )
            return
        provider = parts[0].strip().upper()
        key = parts[1].strip()
        if provider not in _PROVIDER_ENV:
            await self.send_message(
                chat_id, "Noma'lum provayder. GROQ, GEMINI yoki KLING bo'lsin."
            )
            return

        env_name = _PROVIDER_ENV[provider]
        # settings va os.environ ni yangilaymiz, so'ng jonli klientlarni tiklaymiz.
        setattr(settings, env_name, key)
        os.environ[env_name] = key

        # Klientlarni qayta qurish (eski key bilan qolib ketmasin).
        from app.core import dependencies as deps

        deps.refresh_provider_clients(provider.lower())

        await self.send_message(
            chat_id,
            f"✅ <b>{provider}</b> key yangilandi: <code>{_mask(key)}</code>\n"
            "Klientlar yangi key bilan qayta qurildi.",
        )
        logger.info("Telegram: %s key yangilandi (admin=%s)", provider, chat_id)

    async def _cmd_logs(self, chat_id: int, _: str) -> None:
        entries = get_recent_errors(20)
        if not entries:
            await self.send_message(chat_id, "✅ Xatolar yo'q (bufer bo'sh).")
            return
        lines = ["<b>🪵 Oxirgi xatolar</b>"]
        for e in entries:
            msg = html.escape(e.message)
            if len(msg) > 300:
                msg = msg[:300] + "…"
            lines.append(
                f"<code>{_fmt_ts(e.ts)}</code> [{e.level}] {html.escape(e.logger)}\n{msg}"
            )
        await self.send_message(chat_id, "\n\n".join(lines))

    async def _cmd_restart(self, chat_id: int, _: str) -> None:
        from app.core import dependencies as deps

        deps.refresh_all_clients()
        await self.send_message(
            chat_id,
            "♻️ Worker qayta ishga tushirildi — barcha agent klientlari "
            "joriy API key'lar bilan qayta qurildi.",
        )
        logger.info("Telegram: /restart (admin=%s)", chat_id)

    async def _cmd_limits(self, chat_id: int, _: str) -> None:
        await self.send_message(chat_id, "⏳ Limitlar so'ralmoqda...")
        groq = await self._groq_limits()
        gemini = self._gemini_limits()
        kling = await self._kling_limits()
        await self.send_message(
            chat_id,
            "<b>📈 API limitlari</b>\n\n"
            f"<b>Groq</b>\n{groq}\n\n"
            f"<b>Gemini</b>\n{gemini}\n\n"
            f"<b>Kling</b>\n{kling}",
        )

    # ----------------------------------------------------- Health checks ----
    async def _check_groq(self) -> tuple[Optional[bool], str]:
        if not settings.GROQ_API_KEY:
            return False, "key o'rnatilmagan"
        try:
            r = await self._client.get(
                "https://api.groq.com/openai/v1/models",
                headers={"Authorization": f"Bearer {settings.GROQ_API_KEY}"},
            )
            if r.status_code == 200:
                return True, "ulanish OK"
            if r.status_code in (401, 403):
                return False, "key yaroqsiz"
            return None, f"HTTP {r.status_code}"
        except Exception as e:
            return None, f"tarmoq xatosi: {e}"

    async def _check_gemini(self) -> tuple[Optional[bool], str]:
        if not settings.GEMINI_API_KEY:
            return False, "key o'rnatilmagan"
        try:
            r = await self._client.get(
                "https://generativelanguage.googleapis.com/v1beta/models",
                params={"key": settings.GEMINI_API_KEY},
            )
            if r.status_code == 200:
                return True, "ulanish OK"
            if r.status_code in (400, 401, 403):
                return False, "key yaroqsiz"
            return None, f"HTTP {r.status_code}"
        except Exception as e:
            return None, f"tarmoq xatosi: {e}"

    def _check_kling(self) -> tuple[Optional[bool], str]:
        if not settings.KLING_API_KEY:
            return False, "key o'rnatilmagan (video o'chiq)"
        return True, "key o'rnatilgan"

    # ------------------------------------------------------- Limit details --
    async def _groq_limits(self) -> str:
        """Groq rate-limit sarlavhalarini minimal so'rov orqali o'qiydi."""
        if not settings.GROQ_API_KEY:
            return "key o'rnatilmagan"
        try:
            r = await self._client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={"Authorization": f"Bearer {settings.GROQ_API_KEY}"},
                json={
                    "model": "llama-3.3-70b-versatile",
                    "messages": [{"role": "user", "content": "ping"}],
                    "max_tokens": 1,
                },
            )
            h = r.headers
            rpm_lim = h.get("x-ratelimit-limit-requests", "?")
            rpm_rem = h.get("x-ratelimit-remaining-requests", "?")
            tpd_lim = h.get("x-ratelimit-limit-tokens", "?")
            tpd_rem = h.get("x-ratelimit-remaining-tokens", "?")
            if rpm_lim == "?" and r.status_code != 200:
                return f"HTTP {r.status_code} — limit ma'lumoti yo'q"
            return (
                f"So'rovlar: {rpm_rem}/{rpm_lim} qoldi\n"
                f"Tokenlar: {tpd_rem}/{tpd_lim} qoldi"
            )
        except Exception as e:
            return f"so'rab bo'lmadi: {e}"

    def _gemini_limits(self) -> str:
        """Gemini bepul tarif limitlari (nominal — header orqali kelmaydi)."""
        if not settings.GEMINI_API_KEY:
            return "key o'rnatilmagan"
        # gemini-2.5-flash bepul tarif nominal qiymatlari.
        return (
            "So'rovlar/daqiqa: ~15 RPM (nominal)\n"
            "So'rovlar/kun: ~1500 RPD (nominal)\n"
            "<i>Aniq qoldiq Google AI Studio'da ko'rinadi.</i>"
        )

    async def _kling_limits(self) -> str:
        if not settings.KLING_API_KEY:
            return "key o'rnatilmagan (kuniga 66 bepul kredit)"
        # Kling kredit so'rovi JWT (ak/sk) imzolashni talab qiladi — bu yerda
        # nominal ko'rsatamiz; aniq qoldiqni Kling konsolida ko'rish mumkin.
        return (
            "Bepul kredit: ~66/kun (nominal)\n"
            "<i>Aniq qoldiq Kling konsolida ko'rinadi.</i>"
        )


def _chunk(text: str, size: int):
    """Uzun matnni Telegram cheklovi uchun bo'laklarga ajratadi."""
    for i in range(0, len(text), size):
        yield text[i : i + size]


# --------------------------------------------------------------------------- #
# FastAPI integratsiyasi                                                       #
# --------------------------------------------------------------------------- #
_bot = TelegramBot()
telegram_router = APIRouter(prefix="/telegram", tags=["Telegram"])


def get_bot() -> TelegramBot:
    return _bot


@telegram_router.post("/webhook")
async def telegram_webhook(
    request: Request,
    x_telegram_bot_api_secret_token: str = Header(default=""),
):
    """Telegram update'larini qabul qiladi va admin buyruqlarini bajaradi."""
    if not _bot.enabled:
        return {"ok": True, "note": "bot disabled"}

    # Secret token tekshiruvi (o'rnatilgan bo'lsa).
    if settings.TELEGRAM_WEBHOOK_SECRET:
        if x_telegram_bot_api_secret_token != settings.TELEGRAM_WEBHOOK_SECRET:
            logger.warning("Telegram webhook: noto'g'ri secret token")
            return {"ok": False}

    try:
        update = await request.json()
    except Exception:
        return {"ok": False}

    # Update'ni fon vazifa sifatida bajaramiz — Telegram'ga darhol 200 qaytadi.
    asyncio.create_task(_bot.handle_update(update))
    return {"ok": True}


def setup_telegram(app: FastAPI) -> None:
    """main.py shu funksiyani chaqiradi: router'ni ulaydi va webhook o'rnatadi."""
    app.include_router(telegram_router, prefix="/api/v1")

    @app.on_event("startup")
    async def _telegram_startup() -> None:  # pragma: no cover - infra
        if not _bot.enabled:
            logger.info("Telegram bot o'chiq (TELEGRAM_BOT_TOKEN yo'q).")
            return
        if settings.TELEGRAM_WEBHOOK_URL:
            url = settings.TELEGRAM_WEBHOOK_URL.rstrip("/") + "/api/v1/telegram/webhook"
            res = await _bot.set_webhook(url)
            logger.info("Telegram webhook o'rnatildi: %s -> %s", url, res)
        else:
            logger.info(
                "Telegram bot yoqilgan. Webhook'ni qo'lda o'rnating yoki "
                "TELEGRAM_WEBHOOK_URL bering."
            )

    @app.on_event("shutdown")
    async def _telegram_shutdown() -> None:  # pragma: no cover - infra
        await _bot.aclose()
