FROM registry.fedoraproject.org/fedora:42

LABEL org.opencontainers.image.title="Myna Flatpak builder"
LABEL org.opencontainers.image.description="Containerized Flatpak build and test environment for Myna"
LABEL org.opencontainers.image.source="https://github.com/canonical/myna"

# Install Flatpak build tooling inside the container. Nothing here touches the host OS.
RUN dnf -y --setopt=install_weak_deps=False --nodocs install \
        flatpak-builder \
        flatpak \
        git \
        patch \
        python3 \
        python3-pip \
        python3-PyYAML \
        python3-requests \
        bash \
        findutils \
        glibc-langpack-en \
    && dnf clean all

# Flatpak runtimes and SDK extensions needed by the manifest.
# These are installed into the image, not onto the host.
RUN flatpak remote-add --system --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo \
    && flatpak install --system --noninteractive \
        flathub \
        org.gnome.Platform//50 \
        org.gnome.Sdk//50 \
        org.freedesktop.Sdk.Extension.rust-stable//25.08 \
        org.freedesktop.Sdk.Extension.llvm20//25.08

WORKDIR /work

ENV FLATPAK_USER_DIR=/var/lib/flatpak \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

CMD ["/bin/bash"]
