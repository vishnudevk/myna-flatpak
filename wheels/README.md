# Python wheels for offline Flatpak builds

This directory holds pre-built Python wheels used by the backend Flatpak
manifests. It is **gitignored** — populate it before building.

## Whisper backend

```sh
pip download \
    "myna[whisper]" \
    --dest wheels/whisper/ \
    --python-version 3.12 \
    --platform linux_x86_64 \
    --only-binary :all:
```

Or, if building from the upstream source:
```sh
cd ../myna
pip wheel ./server[whisper] -w ../myna-flatpak/wheels/whisper/
```

## Parakeet backend

```sh
pip download \
    "myna[parakeet]" \
    --dest wheels/parakeet/ \
    --python-version 3.12 \
    --platform linux_x86_64 \
    --only-binary :all:
```

## GPU (CUDA) extensions

GPU wheels are large (1–2 GB) and need to be downloaded separately:

```sh
# Whisper CUDA
pip download \
    -r ../myna/whisper-snap/runtimes/faster-whisper-cuda/requirements.txt \
    --dest wheels/whisper-cuda/ \
    --python-version 3.12 \
    --platform linux_x86_64 \
    --only-binary :all:

# Parakeet CUDA
pip download \
    -r ../myna/parakeet-snap/runtimes/onnxruntime-cuda/requirements.txt \
    --dest wheels/parakeet-cuda/ \
    --python-version 3.12 \
    --platform linux_x86_64 \
    --only-binary :all:
```
