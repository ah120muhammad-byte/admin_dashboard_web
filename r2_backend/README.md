# MediData R2 Storage Backend

This service is the server-side bridge between the MediData Admin Dashboard and Cloudflare R2.

## What it does

- Authenticates admin users with Supabase.
- Starts and completes multipart uploads to R2.
- Generates signed upload-part URLs.
- Generates signed download URLs for students/admins.
- Deletes R2 lecture objects.
- Supports large video uploads without routing the file through Supabase.

## Required environment variables

R2_ACCOUNT_ID
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
R2_BUCKET_NAME
R2_ENDPOINT

SUPABASE_URL
SUPABASE_ANON_KEY

Optional:
ALLOWED_ADMIN_USER_IDS

## Endpoints

POST /api/r2/multipart/initiate
POST /api/r2/multipart/part-url
POST /api/r2/multipart/complete
POST /api/r2/multipart/abort
POST /api/r2/signed-url
DELETE /api/r2/object

Health check:
GET /health

The Flutter admin dashboard uses:
--dart-define=R2_BACKEND_URL=<backend-url>

No Telegram credentials or Telegram storage are required by this service.
