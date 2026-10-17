# PORTING NOTES — Myna: Snap → Flatpak

This document records non-obvious design decisions made while porting the
Myna snap packages to Flatpak.

---

## 1. IPC: `inference-provider` content interface → `XDG_RUNTIME_DIR/myna/`

**Snap mechanism:** `snapd` bind-mounts the backend's
`$SNAP_COMMON/share/provider/` directory into the client's
`$SNAP_DATA/backend/provider/`. The backend writes `provider.env` (naming
its socket) and the Unix socket there; the client reads `provider.env` at
each activation to find the live socket.

**Flatpak mechanism:** Both the client and each backend declare:
```yaml
finish-args:
  - --filesystem=xdg-run/myna:create
```
This gives both apps read-write access to `$XDG_RUNTIME_DIR/myna/` (e.g.
`/run/user/1000/myna/`). The backend writes `<adapter>.env` + socket there;
the client's `--backend-dir` flag scans all `*.env` files.

**Open question:** `myna-desktop`'s `--backend-dir` reads files named exactly
`provider.env` inside each connected content share directory in the snap.
The Flatpak side writes `whisper.env` / `parakeet.env` (to allow multiple
backends to coexist without overwriting each other). An upstream patch may be
needed to make `myna-desktop --backend-dir` accept any `*.env` filename rather
than expecting `provider.env` specifically.

---

## 2. Snap components → Flatpak extensions

**Snap mechanism:** Each model-size (tiny, base, small, …) ships as a separate
snap *component* (`type: standard`). A component appears at
`$SNAP_COMPONENTS/<id>/` and carries the model weights directory.

**Flatpak mechanism:** Each model size is a separate Flatpak *extension*
(`add-extensions` in the manifest). Extensions contribute a read-only bind
mount at a declared `directory` inside `/app/` (e.g. `/app/extensions/models/tiny`).
Extensions are independently installable/removable from Flathub.

Flatpak extension mounts are read-only by default (unlike snap's writable
component path), which is correct: model weights are never written at runtime.

---

## 3. modelctl → simple env-var / manifest-default selection

**Snap mechanism:** `modelctl` (from `inference-snaps-cli`) reads engine and
model manifests, probes hardware (lscompute, nvidia-smi), and persists the
selected engine in a JSON cache. The `server.sh` script calls
`modelctl status --format=json | jq -r .engine` to get the active engine.

**Flatpak mechanism:** `modelctl` is a snap-specific binary distributed as a
tarball from `github.com/canonical/inference-snaps-cli`; it cannot run
unmodified in a Flatpak. The Flatpak launcher scripts replace it with:

1. An env var (`MYNA_WHISPER_ENGINE`, `MYNA_PARAKEET_ENGINE`) for manual
   override (useful for GPU users or testing).
2. The `default:` key in `engines/<engine>/engine.yaml` as the built-in
   default (mirrors the `model: default:` field that `modelctl` reads).

Hardware auto-detection (CPU/GPU) is left as a future improvement — either
by shipping a minimal port of `modelctl`'s detection logic, or by exposing
engine selection via `myna-config` / GSettings.

---

## 4. Daemon lifecycle: snap user daemon → systemd user service

**Snap mechanism:** `daemon: simple` + `daemon-scope: user` in `snapcraft.yaml`
makes snapd generate a `systemd --user` unit with
`WantedBy=default.target`, `Restart=on-failure`, `RestartSec=1s`.

**Flatpak mechanism:** We ship an equivalent unit in
`/app/share/systemd/user/`. Flatpak does not auto-enable services; the user
runs `systemctl --user enable --now com.canonical.Myna.service` once
(or the installer / GNOME Software does it on first launch).

The snap's `refresh-mode: restart` (stops and restarts the daemon on every
snap refresh) has no direct Flatpak equivalent; `flatpak update` stops running
apps, so in practice the behavior is similar.

---

## 5. GSettings / keyfile backend

**Snap:** The `myna` daemon app sets `GSETTINGS_BACKEND=keyfile` and
`XDG_CONFIG_HOME=$SNAP_USER_COMMON/.config`, keeping settings in a
snap-private file and surviving `snap revert`.

**Flatpak:** Flatpak's sandbox already redirects `$XDG_CONFIG_HOME` to
`~/.var/app/com.canonical.Myna/config/`. Setting `GSETTINGS_BACKEND=keyfile`
is still desirable to avoid touching host dconf (the host's dconf-service
is reachable over the session bus). The client manifest sets this per-app
in `finish-args` environment overrides, matching the snap's per-app approach.

The `com.canonical.Myna.Dictation.gschema.xml` schema is compiled into
`/app/share/glib-2.0/schemas/` and `GSETTINGS_SCHEMA_DIR` points there.

---

## 6. IBus text injection

**Snap:** Uses the `desktop-legacy` plug (which gives access to the IBus
daemon's private socket at `$DBUS_SESSION_BUS_ADDRESS` equivalent paths).

**Flatpak:** `--socket=session-bus` (already in `finish-args` for D-Bus)
gives access to the session bus where IBus registers. IBus socket discovery
uses `IBUS_ADDRESS` or the well-known socket path; both are accessible with
session-bus access. No additional portal is needed.

---

## 7. HUD (myna-hud) and GNOME Shell extension

**Snap:** `myna-hud` is a GTK4/Adwaita overlay window. On GNOME it is hosted
by the `myna-shell` GNOME Shell extension (shipped in the `myna-config` deb).
On Xfce it is supervised by `myna-hud-host`. The snap's `hud` app uses the
`gnome` extension (Snapcraft extension, not Shell extension) for GTK4
environment setup.

**Flatpak:** GTK4 and libadwaita are provided by `org.gnome.Platform`. The
GNOME Shell extension (`myna-shell`) needs separate packaging as a GNOME
Shell extension archive (`.zip`) — it cannot ship inside the Flatpak. The
`myna-hud` binary itself runs fine inside the Flatpak with Wayland access.

---

## 8. PipeWire client

**Snap:** Stages `libpipewire-0.3-0` + `libpipewire-0.3-modules` and ships a
trimmed set of SPA plugins and PipeWire modules. The `pipewire` snap interface
gives AppArmor/seccomp access to the host PipeWire socket.

**Flatpak:** `org.gnome.Platform` bundles PipeWire. `--device=all` gives
access to `/dev/` nodes; PipeWire socket access is via the portal
(`org.freedesktop.portal.Camera` for microphone is one path, but
`myna-desktop` talks directly to PipeWire, not through the portal). The
`--socket=wayland` finish arg implicitly covers the PipeWire socket path
in most configurations. If the PipeWire socket is not accessible, an explicit
`--filesystem=xdg-run/pipewire-0` may be needed.

---

## 9. NVIDIA GPU support

**Snap:** The `gpu-nvidia` snap component ships CTranslate2/onnxruntime CUDA
pip wheels + NVIDIA cuBLAS/cuDNN libraries. The `opengl` snap interface gives
access to the host driver's `libcuda.so.1`.

**Flatpak:** The `com.canonical.Myna.Whisper.GpuNvidia` extension ships the
same pip wheels. `--device=all` gives access to NVIDIA device nodes and the
host driver. The extension mounts at `/app/extensions/gpu-nvidia/` and its
`site-packages/` is prepended to `PYTHONPATH` by the server launcher when
`MYNA_WHISPER_ENGINE=nvidia-gpu`.
