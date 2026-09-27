#!/bin/sh
set -eu

: "${TELEGRAM_API_ID:?TELEGRAM_API_ID is required}"
: "${TELEGRAM_API_HASH:?TELEGRAM_API_HASH is required}"
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is required}"
: "${TELEGRAM_CHANNEL_ID:?TELEGRAM_CHANNEL_ID is required}"
: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"

export TELEGRAM_HTTP_PORT="${TELEGRAM_LOCAL_PORT:-8081}"
export TELEGRAM_LOCAL=1
export TELEGRAM_WORK_DIR="/var/lib/telegram-bot-api"
export TELEGRAM_TEMP_DIR="/tmp/telegram-bot-api"

mkdir -p "${TELEGRAM_WORK_DIR}" "${TELEGRAM_TEMP_DIR}"

echo "Starting Telegram Local Bot API on port ${TELEGRAM_HTTP_PORT}..."
telegram-bot-api \
  --api-id="${TELEGRAM_API_ID}" \
  --api-hash="${TELEGRAM_API_HASH}" \
  --http-port="${TELEGRAM_HTTP_PORT}" \
  --local \
  --dir="${TELEGRAM_WORK_DIR}" \
  --temp-dir="${TELEGRAM_TEMP_DIR}" \
  --username=telegram-bot-api \
  --groupname=telegram-bot-api &

TELEGRAM_PID=$!

cleanup() {
  kill "${TELEGRAM_PID}" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

echo "Waiting for Telegram Local Bot API..."
for i in $(seq 1 60); do
  if wget -q -O - "http://127.0.0.1:${TELEGRAM_HTTP_PORT}/" >/dev/null 2>&1; then
    echo "Telegram Local Bot API is ready."
    break
  fi
  sleep 1
done

echo "Starting MediData API on Render port ${PORT:-10000}..."
exec python3 -m uvicorn main:app --host 0.0.0.0 --port "${PORT:-10000}"
