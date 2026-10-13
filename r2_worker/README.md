# MediData R2 Worker

A Cloudflare Workers replacement for the old FastAPI/Blitz R2 backend. It keeps the current API routes so the existing Flutter services can continue using the same request contract.

## What it does

- Uses an R2 bucket binding to create, complete, abort and delete objects.
- Returns S3-compatible presigned PUT URLs for each multipart part. Large chunks go directly from the admin browser to R2, not through the Worker.
- Returns short-lived presigned GET URLs to the student app.
- Validates Supabase access tokens. Upload/initiate/part-url/complete/abort/delete require profile role `admin`; requesting a signed video URL requires an authenticated user.
- Adds CORS headers to API responses. Direct browser-to-R2 uploads still require the R2 bucket CORS policy to allow the admin dashboard origin, PUT, and ETag exposure.

## Required configuration

The Worker is configured with:
- Name: `medidata-r2-api`
- R2 bucket binding: `R2_BUCKET` -> the existing `medidata-videos` bucket
- Supabase URL in `wrangler.jsonc`

**Do not create another bucket or copy existing videos.** Use the same bucket that Blitz currently uses.

### Secrets

From the `r2_worker` directory, configure these as Wrangler secrets. Do not commit secret values to GitHub or paste them into chat:

```sh
npx wrangler secret put R2_ACCOUNT_ID
npx wrangler secret put R2_ACCESS_KEY_ID
npx wrangler secret put R2_SECRET_ACCESS_KEY
npx wrangler secret put SUPABASE_ANON_KEY
```

Optionally set `ALLOWED_ADMIN_USER_IDS` to a comma-separated list of admin user UUIDs if you currently use this extra allowlist. Leave it unset to rely on the Supabase `profiles.role = admin` check, consistent with the current backend.

The R2 API token used for signing must have object read/write access to `medidata-videos` so signed video reads and multipart part URLs work.

## Deploy from VS Code

Install Node.js if it is not already installed, then run from the repository root:

```sh
cd r2_worker
npm install
npx wrangler login
npx wrangler types
npx wrangler secret put R2_ACCOUNT_ID
npx wrangler secret put R2_ACCESS_KEY_ID
npx wrangler secret put R2_SECRET_ACCESS_KEY
npx wrangler secret put SUPABASE_ANON_KEY
npx wrangler deploy
```

Paste each value only into Wrangler's interactive prompt. After deploying, Wrangler prints a URL similar to `https://medidata-r2-api.<your-account-subdomain>.workers.dev`.

Test the URL:

```sh
curl https://medidata-r2-api.<your-account-subdomain>.workers.dev/health
```

Expected: `status: ok`, `r2_configured: true`, `r2_ok: true`, and bucket `medidata-videos`.

## Before switching the Flutter apps

1. Test `/health`.
2. Test a small admin multipart upload and verify the database row stores `file_url = r2:<key>`.
3. Test playing and downloading the same video in the student app.
4. Keep Blitz available until upload and playback are verified against the Worker.

## Large-file behavior

The chunk size remains 64 MiB. Those parts are uploaded directly to R2 via presigned URLs, not streamed through the Worker. That retains the current large-file multipart design and avoids Cloudflare Worker request-body limits for the actual video payloads.
