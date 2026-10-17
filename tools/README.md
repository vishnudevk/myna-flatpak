# tools/

Helper scripts used during Flatpak packaging development.
These are committed to the repo; they are not shipped inside any Flatpak.

## flatpak-cargo-generator.py

Downloaded from [flatpak-builder-tools](https://github.com/flatpak/flatpak-builder-tools/tree/master/cargo).

Reads a `Cargo.lock` file and emits a JSON source list (`cargo-sources.json`)
where every crate is a separately downloadable, checksum-verified archive.
`flatpak-builder` expands this list at build time and populates
`cargo/vendor/` so Cargo can build fully offline (Flathub requirement).

### Dependencies

```sh
pip install aiohttp PyYAML tomlkit
```

### Usage

Run this whenever `myna/client/Cargo.lock` changes:

```sh
python3 tools/flatpak-cargo-generator.py \
    myna/client/Cargo.lock \
    -o cargo-sources.json
git add cargo-sources.json
git commit -m "cargo: regenerate sources from Cargo.lock"
```

### Keeping it up to date

`cargo-sources.json` must stay in sync with `client/Cargo.lock`.
If you update myna (e.g. `git -C myna pull`), regenerate and commit.
A CI check comparing the lock file date to the sources file date is a
good guard against drift.

## flatpak-pip-generator.py

Downloaded from [flatpak-builder-tools](https://github.com/flatpak/flatpak-builder-tools/tree/master/pip).

Reads a `requirements.txt` and emits a JSON module manifest (`python3-requirements-whisper.json`)
where each Python dependency is pinned by URL and SHA256 checksum, preferring
pre-compiled wheels.

### Usage

```sh
python3 tools/flatpak-pip-generator.py \
    --runtime org.gnome.Sdk//50 \
    --prefer-wheels=ctranslate2,onnxruntime,numpy,av,tokenizers,protobuf,pyyaml,hf-xet \
    -r requirements-whisper.txt \
    -o python3-requirements-whisper.json
```

