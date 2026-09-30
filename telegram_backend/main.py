import mimetypes
import os
import re
import shutil
import tempfile
from pathlib import Path
from typing import Optional

import httpx
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware

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

app = FastAPI(title="MediData Telegram Video Backend", version="1.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def require_base_env() -> None:
    required = {
        "TELEGRAM_BOT_TOKEN": TELEGRAM_BOT_TOKEN,
        "SUPABASE_URL": SUPABASE_URL,
        "SUPABASE_ANON_KEY": SUPABASE_ANON_KEY,
    }
    missing = [name for name, value in required.items() if not value]
    if missing:
        raise HTTPException(
            status_code=500,
            detail=f"Missing server configuration: {', '.join(missing)}",
        )


def require_upload_env() -> None:
    require_base_env()
    if not TELEGRAM_CHANNEL_ID:
        raise HTTPException(
            status_code=500,
            detail="TELEGRAM_CHANNEL_ID is not configured yet. Discover the channel first.",
        )


async def current_supabase_user(
    authorization: Optional[str] = Header(default=None),
) -> dict:
    require_base_env()

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


async def require_admin_user(user: dict = Depends(current_supabase_user)) -> dict:
    user_id = str(user.get("id", "")).strip()
    if not user_id:
        raise HTTPException(status_code=403, detail="Authenticated user ID is missing")

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{SUPABASE_URL}/rest/v1/profiles",
                params={
                    "select": "role",
                    "id": f"eq.{user_id}",
                    "limit": "1",
                },
                headers={
                    "Authorization": f"Bearer {user.get('_access_token', '')}",
                    "apikey": SUPABASE_ANON_KEY,
                },
            )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail="Supabase profile service is unavailable") from exc

    if response.status_code != 200:
        raise HTTPException(status_code=403, detail="Unable to verify admin role")

    try:
        rows = response.json()
    except ValueError as exc:
        raise HTTPException(status_code=403, detail="Invalid Supabase profile response") from exc

    role = rows[0].get("role") if rows else None
    if role != "admin":
        raise HTTPException(status_code=403, detail="Admin role is required")

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


@app.get("/api/telegram/file/{file_id}")
async def telegram_file(
    file_id: str,
    user: dict = Depends(current_supabase_user),
) -> FileResponse:
    require_base_env()

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                f"{TELEGRAM_API}/bot{TELEGRAM_BOT_TOKEN}/getFile",
                params={"file_id": file_id},
            )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail="Could not reach local Telegram Bot API") from exc

    try:
        data = response.json()
    except ValueError as exc:
        raise HTTPException(status_code=502, detail="Invalid Telegram response") from exc

    if response.status_code != 200 or not data.get("ok"):
        raise HTTPException(
            status_code=404,
            detail=data.get("description", "Telegram file was not found"),
        )

    file_path = str((data.get("result") or {}).get("file_path") or "").strip()
    if not file_path:
        raise HTTPException(status_code=404, detail="Telegram did not return a local file path")

    local_path = Path(file_path).resolve()
    allowed_roots = [
        Path("/var/lib/telegram-bot-api").resolve(),
        Path("/tmp/telegram-bot-api").resolve(),
    ]
    if not any(local_path == root or root in local_path.parents for root in allowed_roots):
        raise HTTPException(status_code=403, detail="Telegram file path is outside the local API storage")
    if not local_path.is_file():
        raise HTTPException(status_code=404, detail="Telegram file is not available on the local API server")

    media_type = mimetypes.guess_type(local_path.name)[0] or "application/octet-stream"
    return FileResponse(
        path=local_path,
        media_type=media_type,
        filename=local_path.name,
        content_disposition_type="inline",
        headers={"Cache-Control": "private, max-age=300"},
    )


@app.delete("/api/telegram/message/{message_id}")
async def delete_telegram_message(
    message_id: int,
    user: dict = Depends(require_admin_user),
) -> JSONResponse:
    require_upload_env()

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(
                f"{TELEGRAM_API}/bot{TELEGRAM_BOT_TOKEN}/deleteMessage",
                json={
                    "chat_id": TELEGRAM_CHANNEL_ID,
                    "message_id": message_id,
                },
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
            detail=data.get("description", "Telegram rejected message deletion"),
        )

    return JSONResponse({"ok": True, "message_id": message_id, "deleted_by": user.get("id")})


@app.get("/api/telegram/channels")
async def telegram_channels(
    user: dict = Depends(require_admin_user),
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
    user: dict = Depends(require_admin_user),
) -> JSONResponse:
    require_upload_env()

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
