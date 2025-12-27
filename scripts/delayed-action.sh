#!/usr/bin/env bash
set -euo pipefail

LOG="$HOME/delayed-action.log"
exec >>"$LOG" 2>&1

echo "Delayed action invoked at $(date)"

# Send a Telegram message if configured
if [ -n "${TG_BOT_TOKEN:-}" ] && [ -n "${TG_CHAT_ID:-}" ]; then
  echo "Sending Telegram notification"
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TG_CHAT_ID}" \
    -d text="⏰ 5h59m completed at $(date)" \
    -d parse_mode="MarkdownV2" >/dev/null || true
else
  echo "TG_BOT_TOKEN or TG_CHAT_ID not set; skipping notification"
fi

# Optionally capture RustDesk ID if available
if command -v rustdesk >/dev/null 2>&1; then
  ID=$(rustdesk --get-id 2>/dev/null || true)
  if [ -n "$ID" ]; then
    echo "RustDesk ID: $ID"
    if [ -n "${TG_BOT_TOKEN:-}" ] && [ -n "${TG_CHAT_ID:-}" ]; then
      curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHAT_ID}" \
        -d text="RustDesk ID: $ID" >/dev/null || true
    fi
  fi
fi

echo "Delayed action completed at $(date)"
