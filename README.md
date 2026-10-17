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

### All-in-One Flatpak with Bundled Whisper Backend

`com.canonical.Myna` bundles both the client (Rust UI, dictation daemon, HUD, status) and the inference backend (`faster-whisper` CTranslate2 Python server). When launched, `myna-app`:

1. Starts `myna-whisper-server` in the background (if not already running).
2. Starts `myna-daemon` in the background (if not already running).
3. Opens the GTK4/Libadwaita Myna Settings GUI (`myna-config`).

### Offline & First-Run Model Provisioning

Models (such as `base` or `tiny`) are stored in `$XDG_DATA_HOME/myna/models/` (`~/.var/app/com.canonical.Myna/data/myna/models/`). If no weights exist on first run, `myna-whisper-server` automatically downloads the default model from Hugging Face via `myna-download-model`. Model sizes can also be manually downloaded with:

```sh
flatpak run --command=myna-download-model com.canonical.Myna <tiny|base|small|large-v3|large-v3-turbo>
```

### Daemon lifecycle: snap user daemon → systemd user service / auto-launch

The Myna desktop entry runs `myna-app`, which supervises both the daemon and backend. Alternatively, the systemd **user service** installed at `/app/share/systemd/user/com.canonical.Myna.service` can be enabled to run Myna at login:

```sh
systemctl --user enable --now com.canonical.Myna.service
```

---

## Building

### Prerequisites

```sh
flatpak install flathub org.gnome.Platform//50 org.gnome.Sdk//50
flatpak install flathub org.freedesktop.Sdk.Extension.rust-stable//25.08
flatpak install flathub org.freedesktop.Sdk.Extension.llvm20//25.08
```

### Build and export the client

```sh
flatpak-builder --disable-rofiles-fuse --repo=repo --force-clean build-dir com.canonical.Myna.yaml
```

### Install locally from repo

```sh
flatpak --user remote-add --if-not-exists --no-gpg-verify myna-local-repo repo
flatpak --user install -y --reinstall myna-local-repo com.canonical.Myna
```

### Run and test

```sh
# Launch Myna Settings GUI:
flatpak run com.canonical.Myna

# Check status of dictation, settings, and connected backends:
flatpak run --command=myna-status com.canonical.Myna

# Start the background dictation daemon:
flatpak run --command=myna-daemon com.canonical.Myna

# Toggle dictation via hotkey / CLI:
flatpak run --command=myna-toggle com.canonical.Myna
```

---

## Status

- [x] Client Flatpak manifest (`com.canonical.Myna.yaml`) complete and verified
- [x] Flathub-compatible offline Cargo vendoring (517 crates in `cargo-sources.json`)
- [x] GNOME 50 + LLVM 20 bindgen paths for `pipewire-sys`
- [x] Builds all 4 components: `myna-desktop`, `myna-hud`, `myna-config`, `myna-testbed`
- [x] Native socket discovery aligned (`/run/user/1000/myna/*/provider.env`)
- [x] AppStream compose validation passing with icons and desktop integration
- [x] Tested locally and confirmed running
- [ ] Inference backend packaging (`com.canonical.Myna.Whisper` / `Parakeet`)
- [ ] Model weights extension manifests

