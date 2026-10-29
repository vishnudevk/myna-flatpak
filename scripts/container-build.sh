#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE="${MYNA_FLATPAK_BUILDER_IMAGE:-localhost/myna-flatpak-builder:latest}"

usage() {
    echo "Usage: $0 [--clean]"
    echo "Builds the Myna Flatpak inside a Podman container."
}

case "${1:-}" in
    "")
        CLEAN=0
        ;;
    --clean|-c)
        CLEAN=1
        shift
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

echo "==> Building container image $IMAGE"
podman build \
    --pull=missing \
    --tag "$IMAGE" \
    --file "$PROJECT_ROOT/Containerfile" \
    "$PROJECT_ROOT"

if [[ "$CLEAN" -eq 1 ]]; then
    echo "==> Requesting clean build"
    podman run \
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
        "$IMAGE" \
        rm -rf .flatpak-builder build-dir
fi

echo "==> Building Myna Flatpak inside $IMAGE"
podman run \
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
    "$IMAGE" \
    flatpak-builder \
        --ccache \
        --disable-rofiles-fuse \
        --repo=repo \
        --force-clean \
        build-dir \
        com.canonical.Myna.yaml

echo "==> Flatpak build complete."
echo "==> Local repository: $PROJECT_ROOT/repo"
echo "==> Use scripts/container-shell.sh for an interactive container shell."
