#!/bin/bash
# scripts/build-flatpak.sh: Container-only wrapper around the Podman build.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

exec "$SCRIPT_DIR/container-build.sh" "$@"
