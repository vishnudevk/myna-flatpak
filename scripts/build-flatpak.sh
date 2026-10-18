#!/bin/bash
# scripts/build-flatpak.sh: Fast incremental Flatpak builder with caching and auto-reinstall.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

if [ "${1:-}" = "--clean" ] || [ "${1:-}" = "-c" ]; then
    echo "==> Wiping flatpak-builder cache and performing clean build..."
    rm -rf .flatpak-builder
else
    echo "==> Performing fast cached build (pass --clean to wipe cache)..."
fi

START_TIME=$(date +%s)

echo "==> Running flatpak-builder with CCACHE and cached modules..."
flatpak-builder \
    --ccache \
    --disable-rofiles-fuse \
    --repo=repo \
    --force-clean \
    build-dir \
    com.canonical.Myna.yaml

BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - START_TIME))

echo "==> Build completed in ${BUILD_DURATION}s."
echo "==> Reinstalling com.canonical.Myna..."
flatpak --user install -y --reinstall myna-local-repo com.canonical.Myna

TOTAL_END_TIME=$(date +%s)
TOTAL_DURATION=$((TOTAL_END_TIME - START_TIME))
echo "==> All done in ${TOTAL_DURATION}s! Run 'flatpak run com.canonical.Myna' to launch."
