# Agent Instructions

This repository ports Myna from Ubuntu/Snap to Flatpak.

## Mandatory container policy

1. **All development, build, and test commands must run inside Podman containers.**
2. **Never install packages, runtimes, SDKs, compilers, or build tools on the host operating system.**
3. **Never invoke `flatpak-builder`, `flatpak install`, `apt`, `dnf`, `pip`, `cargo`, or similar commands directly on the host.**
4. Use the provided container entry points:
   - `scripts/container-build.sh` — build the Flatpak bundle/repo.
   - `scripts/container-test.sh` — run repository checks inside the builder image.
   - `scripts/container-shell.sh` — open an interactive shell in the builder image.
5. The build environment is defined in `Containerfile`; update it there when dependencies change.
6. If a task appears to require a host package or host Flatpak runtime, stop and solve it inside the container image instead.
7. Treat any proposed command that would mutate the host OS as invalid unless the user explicitly overrides this policy.

## Container details

- Runtime: Podman only.
- Builder image: `localhost/myna-flatpak-builder:latest`.
- Build output: `repo/` and `build-dir/`, both inside the repository workspace.
- The builder image installs Flatpak runtimes and SDK extensions system-wide inside the image, not on the host.

## Testing

- Static and integration tests must be launched with `scripts/container-test.sh` or another Podman-based wrapper.
- Do not add test instructions that require host-native dependencies.
- Keep the repository self-contained enough that a fresh clone can be built with Podman alone.

## Repository hygiene

- Keep manifest changes reproducible and checksum-pinned.
- Prefer updating the `Containerfile` over adding host setup steps.
- Preserve the existing Flatpak manifest structure unless a change requires otherwise.
