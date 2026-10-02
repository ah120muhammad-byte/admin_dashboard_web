import os
import re
import uuid
from pathlib import Path
from typing import Optional

import boto3
import httpx
from botocore.client import Config
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

R2_ACCOUNT_ID = os.getenv("R2_ACCOUNT_ID", "").strip()
R2_ACCESS_KEY_ID = os.getenv("R2_ACCESS_KEY_ID", "").strip()
R2_SECRET_ACCESS_KEY = os.getenv("R2_SECRET_ACCESS_KEY", "").strip()
R2_BUCKET_NAME = os.getenv("R2_BUCKET_NAME", "medidata-videos").strip()
R2_ENDPOINT = (
    os.getenv("R2_ENDPOINT", "").strip().rstrip("/")
    or f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
    if R2_ACCOUNT_ID
    else ""
)

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "").strip()
ALLOWED_ADMIN_USER_IDS = {
    value.strip()
    for value in os.getenv("ALLOWED_ADMIN_USER_IDS", "").split(",")
    if value.strip()
}

MAX_UPLOAD_BYTES = 5_000_000_000_000
PART_SIZE = 64 * 1024 * 1024
ALLOWED_EXTENSIONS = {".mp4", ".mov", ".m4v", ".webm", ".avi", ".mkv"}

app = FastAPI(title="MediData R2 Video Backend", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"],
    allow_headers=["Authorization", "Content-Type", "Accept", "Origin", "X-Requested-With"],
    expose_headers=["ETag", "Content-Length", "Content-Type"],
    max_age=86400,
)


@app.options("/{path:path}")
async def cors_preflight(path: str) -> JSONResponse:
    return JSONResponse(
        content={"ok": True},
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD",
            "Access-Control-Allow-Headers": "Authorization, Content-Type, Accept, Origin, X-Requested-With",
            "Access-Control-Max-Age": "86400",
        },
    )


def require_r2_env() -> None:
    required = {
        "R2_ACCOUNT_ID": R2_ACCOUNT_ID,
        "R2_ACCESS_KEY_ID": R2_ACCESS_KEY_ID,
        "R2_SECRET_ACCESS_KEY": R2_SECRET_ACCESS_KEY,
        "R2_BUCKET_NAME": R2_BUCKET_NAME,
        "R2_ENDPOINT": R2_ENDPOINT,
    }
    missing = [name for name, value in required.items() if not value]
    if missing:
        raise HTTPException(
            status_code=500,
            detail=f"Missing server configuration: {', '.join(missing)}",
        )


def require_supabase_env() -> None:
    missing = [
        name
        for name, value in {
            "SUPABASE_URL": SUPABASE_URL,
            "SUPABASE_ANON_KEY": SUPABASE_ANON_KEY,
        }.items()
        if not value
    ]
    if missing:
        raise HTTPException(
            status_code=500,
            detail=f"Missing server configuration: {', '.join(missing)}",
        )


def r2_client():
    require_r2_env()
    return boto3.client(
        "s3",
        endpoint_url=R2_ENDPOINT,
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY,
        region_name="auto",
        config=Config(signature_version="s3v4"),
    )


async def current_supabase_user(
    authorization: Optional[str] = Header(default=None),
) -> dict:
    require_supabase_env()

    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing Supabase access token")

    access_token = authorization.split(" ", 1)[1].strip()
    if not access_token:
        raise HTTPException(status_code=401, detail="Invalid access token")

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                f"{SUPABASE_URL}/auth/v1/user",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "apikey": SUPABASE_ANON_KEY,
                },
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=503,
            detail="Supabase authentication service is unavailable",
        ) from exc

    if response.status_code != 200:
        # Keep the upstream Auth reason visible for diagnostics without ever
        # returning the user's access token or other credentials.
        upstream_detail = response.text.strip().replace("\n", " ")[:240]
        raise HTTPException(
            status_code=401,
            detail=f"Supabase Auth rejected the access token ({response.status_code}): {upstream_detail}",
        )

    try:
        user = response.json()
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid Supabase auth response") from exc

    user_id = str(user.get("id", "")).strip()
    if not user_id:
        raise HTTPException(status_code=401, detail="Authenticated user ID is missing")

    if ALLOWED_ADMIN_USER_IDS and user_id not in ALLOWED_ADMIN_USER_IDS:
        raise HTTPException(status_code=403, detail="User is not allowed to manage videos")

    user["_access_token"] = access_token
    return user


async def require_admin_user(user: dict = Depends(current_supabase_user)) -> dict:
    user_id = str(user.get("id", "")).strip()
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{SUPABASE_URL}/rest/v1/profiles",
                params={"select": "role", "id": f"eq.{user_id}", "limit": "1"},
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

    if not rows or rows[0].get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin role is required")

    return user


def safe_filename(name: str) -> str:
    name = Path(name or "video.mp4").name
    name = re.sub(r"[^A-Za-z0-9._ -]+", "_", name).strip()
    return (name or "video.mp4")[:180]


def build_object_key(lecture_id: str, filename: str) -> str:
    safe = safe_filename(filename).replace(" ", "_")
    lecture = re.sub(r"[^A-Za-z0-9_-]+", "_", lecture_id.strip()) or "lecture"
    return f"lectures/{lecture}/{uuid.uuid4().hex}_{safe}"


class InitiateMultipartRequest(BaseModel):
    lecture_id: str
    filename: str
    content_type: str = "video/mp4"
    file_size: int


class PresignPartRequest(BaseModel):
    key: str
    upload_id: str
    part_number: int


class CompletedPart(BaseModel):
    part_number: int
    etag: str


class CompleteMultipartRequest(BaseModel):
    key: str
    upload_id: str
    parts: list[CompletedPart]


class AbortMultipartRequest(BaseModel):
    key: str
    upload_id: str


class SignedUrlRequest(BaseModel):
    key: str


@app.get("/")
async def root() -> JSONResponse:
    return JSONResponse({
        "service": "MediData R2 Video Backend",
        "status": "ok",
        "bucket": R2_BUCKET_NAME,
    })


@app.get("/health")
async def health() -> JSONResponse:
    configured = bool(
        R2_ACCOUNT_ID and R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY
        and R2_BUCKET_NAME and R2_ENDPOINT
        and SUPABASE_URL and SUPABASE_ANON_KEY
    )
    r2_ok = False
    r2_error = None
    if configured:
        try:
            r2_client().head_bucket(Bucket=R2_BUCKET_NAME)
            r2_ok = True
        except Exception as exc:
            r2_error = f"{type(exc).__name__}: {str(exc)[:300]}"

    return JSONResponse({
        "status": "ok",
        "r2_configured": configured,
        "r2_ok": r2_ok,
        "r2_error": r2_error,
        "bucket": R2_BUCKET_NAME,
    })


@app.post("/api/r2/multipart/initiate")
async def initiate_multipart(
    request: InitiateMultipartRequest,
    user: dict = Depends(require_admin_user),
) -> JSONResponse:
    if request.file_size <= 0:
        raise HTTPException(status_code=400, detail="File size must be greater than zero")
    if request.file_size > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Video exceeds the R2 maximum supported size")

    filename = safe_filename(request.filename)
    if Path(filename).suffix.lower() not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Unsupported video type")

    key = build_object_key(request.lecture_id, filename)
    content_type = request.content_type.strip() or "video/mp4"

    try:
        result = r2_client().create_multipart_upload(
            Bucket=R2_BUCKET_NAME,
            Key=key,
            ContentType=content_type,
            Metadata={
                "lecture-id": request.lecture_id[:200],
                "uploaded-by": str(user.get("id", ""))[:200],
                "original-filename": filename[:200],
            },
        )
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"R2 could not start the multipart upload: {type(exc).__name__}",
        ) from exc

    return JSONResponse({
        "ok": True,
        "key": key,
        "upload_id": result["UploadId"],
        "part_size": PART_SIZE,
        "file_name": filename,
        "file_size": request.file_size,
    })


@app.post("/api/r2/multipart/part-url")
async def presign_part(
    request: PresignPartRequest,
    user: dict = Depends(require_admin_user),
) -> JSONResponse:
    if request.part_number < 1 or request.part_number > 10000:
        raise HTTPException(status_code=400, detail="Invalid part number")
    if not request.key.startswith("lectures/"):
        raise HTTPException(status_code=403, detail="Invalid R2 object key")

    try:
        url = r2_client().generate_presigned_url(
            "upload_part",
            Params={
                "Bucket": R2_BUCKET_NAME,
                "Key": request.key,
                "UploadId": request.upload_id,
                "PartNumber": request.part_number,
            },
            ExpiresIn=3600,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"R2 could not create a signed part URL: {type(exc).__name__}",
        ) from exc

    return JSONResponse({"ok": True, "url": url})


@app.post("/api/r2/multipart/complete")
async def complete_multipart(
    request: CompleteMultipartRequest,
    user: dict = Depends(require_admin_user),
) -> JSONResponse:
    if not request.key.startswith("lectures/") or not request.parts:
        raise HTTPException(status_code=400, detail="Invalid multipart completion request")

    parts = [
        {"PartNumber": part.part_number, "ETag": part.etag}
        for part in sorted(request.parts, key=lambda p: p.part_number)
    ]

    try:
        result = r2_client().complete_multipart_upload(
            Bucket=R2_BUCKET_NAME,
            Key=request.key,
            UploadId=request.upload_id,
            MultipartUpload={"Parts": parts},
        )
        head = r2_client().head_object(Bucket=R2_BUCKET_NAME, Key=request.key)
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"R2 could not complete the multipart upload: {type(exc).__name__}: {str(exc)[:300]}",
        ) from exc

    return JSONResponse({
        "ok": True,
        "key": request.key,
        "etag": result.get("ETag"),
        "file_size": head.get("ContentLength"),
        "content_type": head.get("ContentType"),
        "uploaded_by": user.get("id"),
    })


@app.post("/api/r2/multipart/abort")
async def abort_multipart(
    request: AbortMultipartRequest,
    user: dict = Depends(require_admin_user),
) -> JSONResponse:
    if not request.key.startswith("lectures/"):
        raise HTTPException(status_code=400, detail="Invalid R2 object key")
    try:
        r2_client().abort_multipart_upload(
            Bucket=R2_BUCKET_NAME,
            Key=request.key,
            UploadId=request.upload_id,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"R2 could not abort the multipart upload: {type(exc).__name__}",
        ) from exc

    return JSONResponse({"ok": True})


@app.post("/api/r2/signed-url")
async def signed_url(
    request: SignedUrlRequest,
    user: dict = Depends(current_supabase_user),
) -> JSONResponse:
    if not request.key.startswith("lectures/"):
        raise HTTPException(status_code=403, detail="Invalid R2 object key")

    try:
        url = r2_client().generate_presigned_url(
            "get_object",
            Params={"Bucket": R2_BUCKET_NAME, "Key": request.key},
            ExpiresIn=3600,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"R2 could not create a signed download URL: {type(exc).__name__}",
        ) from exc

    return JSONResponse({"ok": True, "url": url, "expires_in": 3600})


@app.delete("/api/r2/object")
async def delete_object(
    key: str,
    user: dict = Depends(require_admin_user),
) -> JSONResponse:
    if not key.startswith("lectures/"):
        raise HTTPException(status_code=403, detail="Invalid R2 object key")
    try:
        r2_client().delete_object(Bucket=R2_BUCKET_NAME, Key=key)
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"R2 could not delete the object: {type(exc).__name__}",
        ) from exc
    return JSONResponse({"ok": True, "key": key})


@app.post("/api/upload/video")
async def legacy_upload_video(
    file: UploadFile = File(...),
    title: Optional[str] = None,
    lecture_id: Optional[str] = None,
    user: dict = Depends(require_admin_user),
) -> JSONResponse:
    raise HTTPException(
        status_code=410,
        detail="The old Telegram upload endpoint was removed. Use the R2 multipart upload flow.",
    )
