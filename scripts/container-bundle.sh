#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE="${MYNA_FLATPAK_BUILDER_IMAGE:-localhost/myna-flatpak-builder:latest}"
BUNDLE_PATH="${MYNA_FLATPAK_BUNDLE:-dist/com.canonical.Myna.flatpak}"

usage() {
    echo "Usage: $0"
    echo "Creates an installable Flatpak bundle from repo/ inside Podman."
}

case "${1:-}" in
    "")
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

if ! command -v podman >/dev/null 2>&1; then
    echo "error: podman is required, but it was not found on the host" >&2
    exit 1
fi

echo "==> Preparing builder image $IMAGE"
podman build \
    --pull=missing \
    --tag "$IMAGE" \
    --file "$PROJECT_ROOT/Containerfile" \
    "$PROJECT_ROOT"

echo "==> Creating Flatpak bundle inside $IMAGE"
podman run \
    --rm \
    --privileged \
    --network=host \
    --userns=keep-id \
    --env XDG_CACHE_HOME=/tmp \
    --env XDG_STATE_HOME=/tmp \
    --env GIT_PAGER=cat \
    --env LESSHISTFILE=- \
    --env BUNDLE_PATH="$BUNDLE_PATH" \
    --volume "$PROJECT_ROOT":/work:Z \
    --workdir /work \
    "$IMAGE" \
    bash -ceu '
        test -d repo
        mkdir -p "$(dirname "$BUNDLE_PATH")"
        flatpak build-bundle \
            --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo \
            repo \
            "$BUNDLE_PATH" \
            com.canonical.Myna
    '

echo "==> Flatpak bundle complete: $PROJECT_ROOT/$BUNDLE_PATH"
