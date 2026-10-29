#!/usr/bin/env bash
set -euo pipefail

mkdir -p /run/user/0
chmod 700 /run/user/0
export XDG_RUNTIME_DIR=/run/user/0
export MYNA_WHISPER_MODEL=tiny

BUNDLE=/work/dist/com.canonical.Myna.flatpak
TEST_WAV=/tmp/myna-hello.wav
TRANSCRIPT_LOG=/tmp/myna-transcript.log
STATUS_LOG=/tmp/myna-status.log

test -f "$BUNDLE"

echo "==> Installing Myna Flatpak"
flatpak --system install \
    --bundle \
    --noninteractive \
    --reinstall \
    "$BUNDLE"

echo "==> Downloading the tiny Whisper model"
flatpak run --command=myna-download-model com.canonical.Myna tiny

echo "==> Starting PipeWire and WirePlumber"
pipewire >/tmp/pipewire.log 2>&1 &
wireplumber >/tmp/wireplumber.log 2>&1 &
sleep 2

echo "==> Creating the virtual microphone"
timeout 85 pw-loopback \
    --capture-props 'media.class=Audio/Sink node.name=myna-test-feed' \
    --playback-props 'media.class=Audio/Source node.name=myna-test-source node.description=Myna test source' \
    >/tmp/myna-loopback.log 2>&1 &

for _ in {1..30}; do
    pw-cli ls Node > /tmp/myna-nodes.log
    if grep -q 'node.name = "myna-test-source"' /tmp/myna-nodes.log &&
        grep -q 'node.name = "myna-test-feed"' /tmp/myna-nodes.log; then
        break
    fi
    sleep 1
done

grep -q 'node.name = "myna-test-source"' /tmp/myna-nodes.log
grep -q 'node.name = "myna-test-feed"' /tmp/myna-nodes.log

echo "==> Generating TTS audio"
espeak-ng \
    -v en-us \
    -s 125 \
    -w "$TEST_WAV" \
    "Hello, how are you?"

echo "==> Starting the Myna daemon"
flatpak run --command=myna-daemon com.canonical.Myna \
    >/tmp/myna-daemon.log 2>&1 &

for _ in {1..30}; do
    flatpak run --command=myna-status com.canonical.Myna \
        >"$STATUS_LOG" 2>&1 || true
    if grep -q 'whisper-tiny' "$STATUS_LOG"; then
        break
    fi
    sleep 1
done

cat "$STATUS_LOG"
grep -q 'whisper-tiny' "$STATUS_LOG"
grep -q 'daemon ready' /tmp/myna-daemon.log

echo "==> Transcribing virtual microphone audio"
pw-cat --playback --target myna-test-feed "$TEST_WAV" \
    >/tmp/myna-playback.log 2>&1 &

(
    sleep 0.5
    printf '\n'
    sleep 5
) | timeout 30 flatpak run \
    --command=myna-testbed-wrapper \
    com.canonical.Myna \
    --mic \
    --target myna-test-source \
    | tee "$TRANSCRIPT_LOG"

cat "$TRANSCRIPT_LOG"
grep -Eiq 'how are you|hello' "$TRANSCRIPT_LOG"

echo "==> Myna integration test passed"
