# MediData Telegram Video Backend

This service is a server-side bridge between the MediData Admin Dashboard and a private Telegram channel.

## What it does

- Receives an authenticated video upload from the admin dashboard.
- Writes the upload to a temporary local file in chunks.
- Uses Telegram Local Bot API to send the file to the private channel.
- Returns the Telegram message/file identifiers.
- Never exposes the Telegram bot token to Flutter Web.

Telegram Local Bot API is required for videos larger than the normal Bot API upload limit.

## Required Render environment variables

TELEGRAM_API_ID
TELEGRAM_API_HASH
TELEGRAM_BOT_TOKEN
TELEGRAM_CHANNEL_ID (can be added after channel discovery)
SUPABASE_URL
SUPABASE_ANON_KEY

Optional:
ALLOWED_ADMIN_USER_IDS

## Telegram setup

1. Create the bot with @BotFather.
2. Add the bot as an administrator of the private channel.
3. Give it permission to post messages.
4. Obtain API ID and API Hash from https://my.telegram.org.
5. Add all values as Render environment variables.

Do not commit TELEGRAM_BOT_TOKEN to GitHub and do not put it in the Flutter app.

## Render

Create a Web Service from this repository.

Root Directory:
telegram_backend

Runtime:
Docker

The service listens on Render's PORT environment variable.

Health check:
GET /health

## Upload API

POST /api/upload/video

Multipart field:
file

Optional query fields:
title
lecture_id

Authentication:
Authorization: Bearer <Supabase access token>

The response includes:
- message_id
- file_id
- file_unique_id
- file_name
- file_size

These values will later be stored in Supabase lecture_files so the student app can stream/download the Telegram-hosted video without exposing the bot token.

## Important

Render Free uses an ephemeral filesystem and can spin down after 15 minutes of inactivity. The video is only stored there while being processed; the intended persistent storage is Telegram.


## First-time channel ID discovery

You can deploy without TELEGRAM_CHANNEL_ID initially.

After the bot is an administrator in the private channel, post a new message in that channel. Then call:
GET /api/telegram/channels
with the same Supabase access token used by the Admin Dashboard.

The endpoint returns channel IDs visible to the bot. Put the selected ID into the Render TELEGRAM_CHANNEL_ID environment variable and redeploy.
