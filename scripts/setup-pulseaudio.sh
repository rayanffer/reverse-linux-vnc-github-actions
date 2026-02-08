#!/bin/bash
set -e

echo "🔊 Setting up PulseAudio virtual sink for RustDesk"

# --------------------------------------------------
# Install dependencies
# --------------------------------------------------
sudo apt-get update
sudo apt-get install -y pulseaudio pulseaudio-utils pavucontrol

# --------------------------------------------------
# Runtime directory (CRITICAL for headless/CI)
# --------------------------------------------------
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
sudo mkdir -p "$XDG_RUNTIME_DIR"
sudo chown "$(id -u)":"$(id -g)" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# --------------------------------------------------
# Kill stale PulseAudio (run as USER, not root)
# --------------------------------------------------
pulseaudio --kill >/dev/null 2>&1 || true
sleep 1

# --------------------------------------------------
# Start PulseAudio (headless-safe)
# --------------------------------------------------
pulseaudio --start --exit-idle-time=-1
sleep 2

# --------------------------------------------------
# Verify PulseAudio
# --------------------------------------------------
if ! pactl info >/dev/null 2>&1; then
  echo "❌ PulseAudio failed to start"
  exit 1
fi

echo "✅ PulseAudio running"

# --------------------------------------------------
# Create virtual sink (idempotent)
# --------------------------------------------------
if ! pactl list short sinks | grep -q rustdesk_sink; then
  pactl load-module module-null-sink \
    sink_name=rustdesk_sink \
    sink_properties=device.description=RustDesk_Sink
  echo "✅ Created sink: rustdesk_sink"
else
  echo "ℹ️ Sink already exists"
fi

# --------------------------------------------------
# Set defaults (THIS IS THE IMPORTANT PART)
# --------------------------------------------------
pactl set-default-sink rustdesk_sink
pactl set-default-source rustdesk_sink.monitor

# --------------------------------------------------
# Move existing streams (safe if none exist)
# --------------------------------------------------
for stream in $(pactl list short sink-inputs | awk '{print $1}'); do
  pactl move-sink-input "$stream" rustdesk_sink || true
done

for stream in $(pactl list short source-outputs | awk '{print $1}'); do
  pactl move-source-output "$stream" rustdesk_sink.monitor || true
done

# --------------------------------------------------
# Environment variables RustDesk relies on
# --------------------------------------------------
export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
export PULSE_SOURCE="rustdesk_sink.monitor"
export SDL_AUDIODRIVER=pulseaudio

# --------------------------------------------------
# Persist env vars (GitHub Actions compatible)
# --------------------------------------------------
if [[ -n "$GITHUB_ENV" ]]; then
  {
    echo "PULSE_SERVER=$PULSE_SERVER"
    echo "PULSE_SOURCE=$PULSE_SOURCE"
    echo "SDL_AUDIODRIVER=$SDL_AUDIODRIVER"
  } >> "$GITHUB_ENV"
fi

# --------------------------------------------------
# Final sanity output
# --------------------------------------------------
echo "🎧 RustDesk audio routing ready"
echo "🔈 Sink: rustdesk_sink"
echo "📡 Source: rustdesk_sink.monitor"

pactl list short sinks
pactl list short sources

exit 0
