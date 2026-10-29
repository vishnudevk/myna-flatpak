#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE="${MYNA_FLATPAK_BUILDER_IMAGE:-localhost/myna-flatpak-builder:latest}"

usage() {
    echo "Usage: $0"
    echo "Runs the upstream Rust test suite inside the Podman builder image."
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

echo "==> Running Cargo tests inside $IMAGE"
podman run \
    --rm \
    --privileged \
    --network=host \
    --userns=keep-id \
    --env XDG_CACHE_HOME=/tmp \
    --env XDG_STATE_HOME=/tmp \
    --env GIT_PAGER=cat \
    --env LESSHISTFILE=- \
    --env CARGO_HOME=/tmp/cargo \
    --env CARGO_TARGET_DIR=/tmp/myna-target \
    --env RUST_BACKTRACE=1 \
    --env BINDGEN_EXTRA_CLANG_ARGS=-I/usr/lib/clang/20/include \
    --volume "$PROJECT_ROOT":/work:Z \
    --workdir /work \
    "$IMAGE" \
    bash -ceu '
        rm -rf .tmp/myna-src
        git clone -q https://github.com/canonical/myna.git .tmp/myna-src
        git -C .tmp/myna-src checkout -q f9ddecc8888815e3a732b7b40071e552bab02bab
        for patch in /work/patches/*.patch; do
            git -C .tmp/myna-src apply "$patch"
        done
        cargo test --locked --all --manifest-path .tmp/myna-src/client/Cargo.toml -- \
            --skip the_hud_hosts_itself_on_x11 \
            --skip wav_dictation_round_trip_against_real_server \
            --skip wav_dictation_round_trip_over_ie115_dialect \
            --skip fake_server_round_trip
    '

echo "==> Cargo tests passed."
