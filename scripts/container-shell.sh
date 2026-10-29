#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE="${MYNA_FLATPAK_BUILDER_IMAGE:-localhost/myna-flatpak-builder:latest}"

usage() {
    echo "Usage: $0 [command...]"
    echo "Starts an interactive shell in the Myna Flatpak builder container."
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
esac

if ! command -v podman >/dev/null 2>&1; then
    echo "error: podman is required, but it was not found on the host" >&2
    exit 1
fi

podman build \
    --pull=missing \
    --tag "$IMAGE" \
    --file "$PROJECT_ROOT/Containerfile" \
    "$PROJECT_ROOT"

exec podman run \
    --rm \
    --privileged \
    --network=host \
    --userns=keep-id \
    --env XDG_CACHE_HOME=/tmp \
    --env XDG_STATE_HOME=/tmp \
    --env GIT_PAGER=cat \
    --env LESSHISTFILE=- \
    --volume "$PROJECT_ROOT":/work:Z \
    --workdir /work \
    --interactive \
    --tty \
    "$IMAGE" \
    "${@:-/bin/bash}"
