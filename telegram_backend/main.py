import os
import re
import shutil
import tempfile
from pathlib import Path
from typing import Optional

import httpx
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.responses import JSONResponse

TELEGRAM_LOCAL_PORT = int(os.getenv("TELEGRAM_LOCAL_PORT", "8081"))
TELEGRAM_API = f"http://127.0.0.1:{TELEGRAM_LOCAL_PORT}"
TELEGRAM_CHANNEL_ID = os.getenv("TELEGRAM_CHANNEL_ID", "").strip()
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "").strip()
ALLOWED_ADMIN_USER_IDS = {
    value.strip()
    for value in os.getenv("ALLOWED_ADMIN_USER_IDS", "").split(",")
    if value.strip()
}

MAX_UPLOAD_BYTES = 2_000_000_000
ALLOWED_EXTENSIONS = {
    ".mp4", ".mov", ".m4v", ".webm", ".avi", ".mkv"
}

app = FastAPI(title="MediData Telegram Video Backend", version="1.0.0")


def require_env() -> None:
    required = {
        "TELEGRAM_BOT_TOKEN": TELEGRAM_BOT_TOKEN,
        "TELEGRAM_CHANNEL_ID": TELEGRAM_CHANNEL_ID,
        "SUPABASE_URL": SUPABASE_URL,
        "SUPABASE_ANON_KEY": SUPABASE_ANON_KEY,
    }
    missing = [name for name, value in required.items() if not value]
    if missing:
        raise HTTPException(
            status_code=500,
            detail=f"Missing server configuration: {', '.join(missing)}",
        )


async def current_supabase_user(
    authorization: Optional[str] = Header(default=None),
) -> dict:
    require_env()

    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing Supabase access token")

    access_token = authorization.split(" ", 1)[1].strip()
    if not access_token:
        raise HTTPException(status_code=401, detail="Invalid access token")

    headers = {
        "Authorization": f"Bearer {access_token}",
        "apikey": SUPABASE_ANON_KEY,
    }

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                f"{SUPABASE_URL}/auth/v1/user",
                headers=headers,
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=503,
            detail="Supabase authentication service is unavailable",
        ) from exc

    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="Invalid or expired Supabase session")

    try:
        user = response.json()
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid Supabase auth response") from exc

    user_id = str(user.get("id", ""))
    if not user_id:
        raise HTTPException(status_code=401, detail="Authenticated user ID is missing")

    if ALLOWED_ADMIN_USER_IDS and user_id not in ALLOWED_ADMIN_USER_IDS:
        raise HTTPException(status_code=403, detail="User is not allowed to upload videos")

    return user


def safe_filename(name: str) -> str:
    name = Path(name or "video.mp4").name
    name = re.sub(r"[^A-Za-z0-9._ -]+", "_", name).strip()
    if not name:
        name = "video.mp4"
    return name[:180]


async def send_local_document(file_path: Path, filename: str, caption: str = "") -> dict:
    uri = file_path.as_uri()
    payload = {
        "chat_id": TELEGRAM_CHANNEL_ID,
        "document": uri,
        "disable_content_type_detection": False,
    }
    if caption:
        payload["caption"] = caption[:1024]

    try:
        async with httpx.AsyncClient(timeout=None) as client:
            response = await client.post(
                f"{TELEGRAM_API}/bot{TELEGRAM_BOT_TOKEN}/sendDocument",
                json=payload,
            )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail="Could not reach local Telegram Bot API") from exc

    try:
        data = response.json()
    except ValueError:
        data = {"ok": False, "description": response.text[:1000]}

    if response.status_code != 200 or not data.get("ok"):
        raise HTTPException(
            status_code=502,
            detail=data.get("description", "Telegram rejected the upload"),
        )

    return data["result"]


@app.get("/")
async def root() -> JSONResponse:
    return JSONResponse(
        {
            "service": "MediData Telegram Video Backend",
            "status": "ok",
            "telegram_local_api": TELEGRAM_API,
        }
    )


@app.get("/health")
async def health() -> JSONResponse:
    telegram_ok = False
    telegram_error = None
    bot = None

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            response = await client.get(
                f"{TELEGRAM_API}/bot{TELEGRAM_BOT_TOKEN}/getMe"
            )
            data = response.json()
            telegram_ok = response.status_code == 200 and data.get("ok", False)
            if telegram_ok:
                bot = data.get("result")
            else:
                telegram_error = data.get("description", response.text[:500])
    except (httpx.HTTPError, ValueError) as exc:
        telegram_error = str(exc)

    return JSONResponse(
        {
            "status": "ok",
            "telegram_local_api": telegram_ok,
            "telegram_error": telegram_error,
            "bot_username": bot.get("username") if bot else None,
        }
    )


@app.get("/api/telegram/channels")
async def telegram_channels(
    user: dict = Depends(current_supabase_user),
) -> JSONResponse:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{TELEGRAM_API}/bot{TELEGRAM_BOT_TOKEN}/getUpdates",
                params={"limit": 100, "allowed_updates": '["channel_post","my_chat_member"]'},
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail="Could not reach local Telegram Bot API",
        ) from exc

    try:
        data = response.json()
    except ValueError as exc:
        raise HTTPException(status_code=502, detail="Invalid Telegram response") from exc

    if response.status_code != 200 or not data.get("ok"):
        raise HTTPException(
            status_code=502,
            detail=data.get("description", "Telegram rejected the request"),
        )

    channels = {}
    for update in data.get("result", []):
        for key in ("channel_post", "edited_channel_post", "my_chat_member"):
            obj = update.get(key) or {}
            chat = obj.get("chat") or {}
            if chat.get("type") == "channel":
                channels[str(chat.get("id"))] = {
                    "id": chat.get("id"),
                    "title": chat.get("title"),
                    "username": chat.get("username"),
                }

    return JSONResponse(
        {
            "ok": True,
            "channels": list(channels.values()),
            "requested_by": user.get("id"),
        }
    )


@app.post("/api/upload/video")
async def upload_video(
    file: UploadFile = File(...),
    title: Optional[str] = None,
    lecture_id: Optional[str] = None,
    user: dict = Depends(current_supabase_user),
) -> JSONResponse:
    require_env()

    filename = safe_filename(file.filename or "video.mp4")
    extension = Path(filename).suffix.lower()

    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported video type: {extension or 'unknown'}",
        )

    temp_dir = Path(tempfile.mkdtemp(prefix="medidata-video-"))
    target = temp_dir / filename

    try:
        total = 0
        with target.open("wb") as output:
            while True:
                chunk = await file.read(8 * 1024 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                if total > MAX_UPLOAD_BYTES:
                    raise HTTPException(
                        status_code=413,
                        detail="Video exceeds the 2GB Telegram local API limit",
                    )
                output.write(chunk)

        caption_parts = [
            f"MediData video: {title.strip()}" if title and title.strip() else f"MediData video: {filename}",
        ]
        if lecture_id and lecture_id.strip():
            caption_parts.append(f"Lecture ID: {lecture_id.strip()}")
        caption_parts.append(f"Uploaded by: {user.get('email') or user.get('id')}")

        message = await send_local_document(
            target,
            filename,
            "\n".join(caption_parts),
        )

        document = message.get("document") or {}
        return JSONResponse(
            {
                "ok": True,
                "provider": "telegram",
                "chat_id": TELEGRAM_CHANNEL_ID,
                "message_id": message.get("message_id"),
                "file_id": document.get("file_id"),
                "file_unique_id": document.get("file_unique_id"),
                "file_name": document.get("file_name") or filename,
                "file_size": document.get("file_size") or total,
                "uploaded_by": user.get("id"),
            }
        )
    finally:
        try:
            shutil.rmtree(temp_dir, ignore_errors=True)
        except OSError:
            pass
