#!/bin/bash

# * install rustdesk
echo "Installing RustDesk..."
wget https://github.com/rustdesk/rustdesk/releases/download/1.4.4/rustdesk-1.4.4-x86_64.deb > /dev/null 2>&1
sudo apt install -fy ./rustdesk*.deb

# * Ensure we run RustDesk in the user account (runner) on the VNC display
export DISPLAY=${DISPLAY:-:1}
LOGFILE="$HOME/rustdesk.log"
touch "$LOGFILE"
sleep 5s

# * Set RustDesk password (if provided) — allow sudo if needed, but preserve HOME so config is written in the right place
if [ -n "$VNC_PASSWORD" ]; then
	echo "Setting RustDesk password (as user $(whoami), HOME=$HOME)" >>"$LOGFILE"
	# Ensure the expected config directory exists and has restrictive perms
	mkdir -p "$HOME/.config/rustdesk"
	chmod 700 "$HOME/.config/rustdesk"
	# First try without sudo (preferred)

	echo "Trying to set password with sudo (preserving HOME/DISPLAY)" >>"$LOGFILE"
	# Use sudo but preserve HOME and DISPLAY so rustdesk writes to the correct per-user path
	sudo env HOME="$HOME" DISPLAY="$DISPLAY" rustdesk --password "${VNC_PASSWORD}@rust69" >>"$LOGFILE" 2>&1 || true
	# Make sure the config files are owned by the original user so the later rustdesk run can read them
	sudo chown -R "$USER":"$USER" "$HOME/.config/rustdesk"
fi

# Start RustDesk in background as the user (use `rustdesk &` as requested)
export DISPLAY=$DISPLAY
rustdesk >>"$LOGFILE" 2>&1 &
RS_PID=$!
echo "RustDesk started (PID: $RS_PID)" 

# Give RustDesk a moment to start and print its ID
DISPLAY=$DISPLAY rustdesk --get-id

# Print where logs are and show recent output for visibility in CI logs
echo "RustDesk log: $LOGFILE"
tail -n 40 "$LOGFILE" || true

# * === TELEGRAM CONFIG ===
BOT_TOKEN=$TG_BOT_TOKEN
CHAT_ID=$TG_CHAT_ID

send_message() {
  local MESSAGE="$1"
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="${MESSAGE}" \
    -d parse_mode="MarkdownV2" > /dev/null
}

# Message on start
send_message "🚀 Rustdesk running on: \`$(rustdesk --get-id)\`"

send_message "C:\\Progra~1\\RustDesk\\rustdesk.exe --connect $(rustdesk --get-id) --password ${VNC_PASSWORD}@rust69"

# Schedule non-blocking notification after 5 hours 55 minutes (5*3600 + 55*60 = 21300 seconds)
( sleep 21300 && send_message "⏰ 5h 55m completed at $(date)" ) &

echo "Scheduled final notification (in 5h55m)" >>"$LOGFILE"

exit