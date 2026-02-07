#!/bin/bash
set -e

echo "🔊 Setting up PulseAudio virtual sink for RustDesk"

# --- Install PulseAudio ---
sudo apt-get install -y pulseaudio pulseaudio-utils pavucontrol

# --- Ensure runtime dir exists (important in CI/headless) ---
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# --- Kill any stale PulseAudio instance ---
pulseaudio --kill >/dev/null 2>&1 || true
sleep 1

# --- Start PulseAudio (headless-safe) ---
pulseaudio --start --daemonize=true --exit-idle-time=-1
sleep 2

# --- Verify PulseAudio is running ---
if ! pactl info >/dev/null 2>&1; then
  echo "❌ PulseAudio failed to start"
  exit 1
fi

echo "✅ PulseAudio started"

# --- Create virtual sink if it doesn't already exist ---
if ! pactl list short sinks | grep -q rustdesk_sink; then
  pactl load-module module-null-sink \
    sink_name=rustdesk_sink \
    sink_properties=device.description=RustDesk_Sink
  echo "✅ Created virtual sink: rustdesk_sink"
else
  echo "ℹ️ Virtual sink already exists"
fi

# --- Set virtual sink as default ---
pactl set-default-sink rustdesk_sink

# --- Move any existing audio streams into the sink ---
for stream in $(pactl list short sink-inputs | awk '{print $1}'); do
  pactl move-sink-input "$stream" rustdesk_sink || true
done

# --- Export env vars RustDesk relies on ---
export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
export SDL_AUDIODRIVER=pulseaudio

# --- Persist env vars for subsequent steps (GitHub Actions compatible) ---
if [[ -n "$GITHUB_ENV" ]]; then
  echo "PULSE_SERVER=$PULSE_SERVER" >> "$GITHUB_ENV"
  echo "SDL_AUDIODRIVER=$SDL_AUDIODRIVER" >> "$GITHUB_ENV"
fi

echo "🎧 PulseAudio routing ready for RustDesk"
echo "📡 Monitor source: rustdesk_sink.monitor"

exit 0
