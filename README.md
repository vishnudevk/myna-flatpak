# myna-flatpak

Flatpak packaging for [Myna](https://github.com/canonical/myna) — local,
offline speech-to-text for the Linux desktop.

Myna is developed and distributed by Canonical as a set of **snap** packages.
This repo ports that packaging to **Flatpak** so Myna can be distributed
on [Flathub](https://flathub.org) and used on distributions other than Ubuntu.

---

## Packages

| Flatpak ID | What it is |
|---|---|
| `com.canonical.Myna` | Client app (Rust): daemon, HUD overlay, testbed CLI |
| `com.canonical.Myna.Whisper` | Whisper inference backend (faster-whisper / CTranslate2) |
| `com.canonical.Myna.Parakeet` | Parakeet TDT 0.6B v3 inference backend (onnxruntime) |

Model weights and GPU runtime ship as **Flatpak extensions**
(equivalent to snap components):

```
com.canonical.Myna.Whisper.Model.Tiny
com.canonical.Myna.Whisper.Model.Base          ← installed by default
com.canonical.Myna.Whisper.Model.Small
com.canonical.Myna.Whisper.Model.LargeV3
com.canonical.Myna.Whisper.Model.LargeV3Turbo
com.canonical.Myna.Whisper.GpuNvidia

com.canonical.Myna.Parakeet.Model.Int8         ← installed by default
com.canonical.Myna.Parakeet.Model.Fp32
com.canonical.Myna.Parakeet.GpuNvidia
```

---

## Snap → Flatpak translation

### IPC: backend socket sharing

In the snap, the inference backend shares its Unix socket with the client
via snapd's **`inference-provider` content interface** — a bind-mounted
directory written by the backend and read by the client.

In Flatpak this is replaced by a shared path in `$XDG_RUNTIME_DIR/myna/`
(both apps declare `--filesystem=xdg-run/myna:create`). The backend writes
a `<name>.env` file beside its socket:

```
MYNA_SOCKET=/run/user/1000/myna/whisper.sock
MYNA_FLATPAK_APP=com.canonical.Myna.Whisper
```

The client's `--backend-dir` flag scans every `*.env` in that directory and
connects to the first live socket — the same discovery logic the daemon uses
in the snap, just with a different directory.

### Model weights: snap components → Flatpak extensions

Snap's **components** (per-model snap archives) map cleanly to Flatpak
**extensions** — independently installable add-ons that contribute a
read-only mount at a declared directory inside the app's `/app/extensions/`.

### Engine selection: modelctl → env vars / manifest defaults

The snap uses `modelctl` (from `inference-snaps-cli`) for engine/model
selection and hardware probing. `modelctl` is snap-specific. In Flatpak
the active engine and model are resolved from:

1. `MYNA_WHISPER_ENGINE` / `MYNA_PARAKEET_ENGINE` env var (override)
2. The `default:` key in `engines/<engine>/engine.yaml` (manifest default)

A future `myna-config` subcommand will expose this via GSettings
(`com.canonical.Myna.Dictation`).

### Daemon lifecycle: snap user daemon → systemd user service

The snap's `daemon: simple` + `daemon-scope: user` maps to a systemd
**user service** installed by the Flatpak at
`/app/share/systemd/user/com.canonical.Myna.service`. Enable it once:

```sh
systemctl --user enable --now com.canonical.Myna.service
```

---

## Building

### Prerequisites

```sh
flatpak install flathub org.gnome.Platform//47 org.gnome.Sdk//47
flatpak install flathub org.freedesktop.Sdk.Extension.rust-stable
```

### Build the client

```sh
flatpak-builder --user --install build/ com.canonical.Myna.yaml
```

### Build a backend

```sh
# Populate the wheels/ directory first (see wheels/README.md)
flatpak-builder --user --install build-whisper/ com.canonical.Myna.Whisper.yaml
```

---

## Installing (once on Flathub)

```sh
flatpak install flathub com.canonical.Myna
flatpak install flathub com.canonical.Myna.Whisper
# Default model (base) installs automatically; add more:
flatpak install flathub com.canonical.Myna.Whisper.Model.Small

# Enable the daemons
systemctl --user enable --now com.canonical.Myna.service
systemctl --user enable --now com.canonical.Myna.Whisper.service

# Bind a hotkey to toggle dictation (writes to host dconf):
flatpak run --command=myna-install-shortcut com.canonical.Myna
```

---

## Repository layout

```
com.canonical.Myna.yaml             ← client Flatpak manifest
com.canonical.Myna.Whisper.yaml     ← Whisper backend manifest
com.canonical.Myna.Parakeet.yaml    ← Parakeet backend manifest
com.canonical.Myna.desktop          ← XDG desktop entry
com.canonical.Myna.metainfo.xml     ← AppStream metadata
scripts/
  myna-daemon                       ← daemon launcher (adapted from snap)
  myna-status                       ← status CLI launcher
  myna-config                       ← config CLI wrapper
  myna-testbed-wrapper              ← testbed CLI launcher
  whisper-server                    ← Whisper backend launcher
  parakeet-server                   ← Parakeet backend launcher
  write-provider-env                ← writes provider.env for client discovery
services/
  com.canonical.Myna.service        ← systemd user service (client)
  com.canonical.Myna.Whisper.service
  com.canonical.Myna.Parakeet.service
wheels/                             ← (gitignored) pre-built Python wheels
  README.md                         ← how to populate this directory
```

---

## Status

Early port — **not yet functional**. The Flatpak manifests faithfully
translate the snap architecture but several items remain:

- [ ] Confirm `myna-desktop` `--backend-dir` accepts `*.env` file format (may need an upstream patch if socket discovery only reads `provider.env` by exact name)
- [ ] Wire `myna-install-shortcut` in Flatpak (dconf write needs `--socket=session-bus` and host dconf path)
- [ ] Populate `wheels/` for offline builds and vendor Cargo dependencies
- [ ] Build and test the Rust workspace inside the Flatpak SDK
- [ ] Create model-weight extension manifests for each model size
- [ ] Create GPU extension manifests (CUDA pip wheels)
- [ ] CI: GitHub Actions workflow building all manifests

See [PORTING-NOTES.md](PORTING-NOTES.md) for detailed design decisions.
