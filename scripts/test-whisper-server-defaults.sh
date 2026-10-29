#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p \
    "$TMP/bin" \
    "$TMP/home" \
    "$TMP/config/myna" \
    "$TMP/data/myna/models/tiny" \
    "$TMP/data/myna/cuda/lib" \
    "$TMP/run/user"

cat >"$TMP/bin/python3" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$MOCK_OUTPUT"
EOF
chmod +x "$TMP/bin/python3"

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_DATA_HOME="$TMP/data"
export XDG_RUNTIME_DIR="$TMP/run/user"
export PATH="$TMP/bin:$PATH"

printf 'cpu\n' >"$XDG_CONFIG_HOME/myna/engine"
printf 'tiny\n' >"$XDG_CONFIG_HOME/myna/model"
export MOCK_OUTPUT="$TMP/cpu.args"
"$PROJECT_ROOT/scripts/whisper-server"

grep -q -- '--sleep-idle-seconds 300' "$MOCK_OUTPUT"
grep -q -- '--idle-action unload' "$MOCK_OUTPUT"

printf 'nvidia-gpu\n' >"$XDG_CONFIG_HOME/myna/engine"
touch "$XDG_DATA_HOME/myna/cuda/lib/libcublas.so.12"
export MOCK_OUTPUT="$TMP/gpu.args"
"$PROJECT_ROOT/scripts/whisper-server"

grep -q -- '--sleep-idle-seconds 600' "$MOCK_OUTPUT"
grep -q -- '--idle-action unload' "$MOCK_OUTPUT"
