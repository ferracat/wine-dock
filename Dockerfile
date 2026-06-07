# Base (~1.7–2GB): Debian bookworm + WineHQ amd64/i386, without winetricks
# Apps 32-bit heavy or winetricks: make image-full
FROM debian:bookworm-slim

# contrib: winetricks etc. — not installed by default; available via apt after make image
RUN sed -i 's/Components: main/Components: main contrib/' /etc/apt/sources.list.d/debian.sources

ARG DISTRO_CODENAME=bookworm
ARG WINE_MONO_VERSION=10.1.0
ARG EZA_VERSION=0.23.4

# Set timezone to Lisbon time (WET) and upgrade
ARG TZ=Europe/Lisbon
ENV TZ=$TZ

RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends tzdata && \
    apt upgrade -y

ARG USERNAME=wine
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND="noninteractive"
ENV WINEPREFIX="/home/$USERNAME/.wine"
ENV WINEARCH="win64"
ENV WINEDEBUG="-all"
ENV XDG_RUNTIME_DIR="/tmp/runtime-$USERNAME"

RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        cabextract \
        gnupg \
        sudo \
        tar \
        unzip \
        usbutils \
        wget \
        xauth \
        xvfb \
    && mkdir -pm755 /etc/apt/keyrings \
    && wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && wget -qNP /etc/apt/sources.list.d/ \
        https://dl.winehq.org/wine-builds/debian/dists/${DISTRO_CODENAME}/winehq-${DISTRO_CODENAME}.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends winehq-stable \
    && apt-get purge -y gnupg \
    && apt-get autoremove -y --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g $GID $USERNAME \
    && useradd -m -s /bin/bash -u $UID -g $GID $USERNAME \
    && mkdir -p /home/$USERNAME/installers /home/$USERNAME/data /home/$USERNAME/.wine \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Get tini - a tiny but valid init process (PID 1) that helps handle zombie processes
# and signal forwarding in containers. Version 0.19.0 is used for stability.
RUN wget -qO /sbin/tini https://github.com/krallin/tini/releases/download/v0.19.0/tini-amd64 && \
    chmod +x /sbin/tini

# eza — modern ls for dev shells (MIT; downloaded at build time)
RUN wget -qO /tmp/eza.tar.gz \
    "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" \
    && tar -xzf /tmp/eza.tar.gz -C /usr/local/bin \
    && chmod 755 /usr/local/bin/eza \
    && rm /tmp/eza.tar.gz

# Wine Mono license text (MSI downloaded at build time; see sources/wine-mono/README)
RUN install -d /usr/share/doc/wine-mono
COPY sources/wine-mono/COPYING /usr/share/doc/wine-mono/COPYING

# --- Switch user and set environment -----------------------------------------
USER $USERNAME

# Initialize Wine and install required components:
# - Initialize Wine environment with wineboot
# - Install core Windows fonts and GDI+ graphics library via winetricks
# - Configure Wine to use Windows 10 compatibility mode
RUN wine wineboot --init && \
    wine winecfg /v win10

# Shortcut in $HOME to the Windows C: drive (follows WINEPREFIX mount at runtime)
RUN ln -sfn .wine/drive_c

# Create runtime directory for X11
RUN install -d -m 0700 $XDG_RUNTIME_DIR

# Optional Windows DLLs (e.g. msvbvm60.dll) — drop into sources/dlls/ before build; skipped if empty
COPY --chown=$USERNAME:$USERNAME sources/dlls/ /tmp/host-dlls/
RUN for f in /tmp/host-dlls/*.dll; do \
      [ -f "$f" ] || continue; \
      cp "$f" "/home/${USERNAME}/.wine/drive_c/windows/syswow64/"; \
    done \
    && rm -rf /tmp/host-dlls

# Install Wine Mono (.NET replacement for Wine)
# Override version: docker build --build-arg WINE_MONO_VERSION=11.0.0 …
RUN WINE_MONO_MSI="wine-mono-${WINE_MONO_VERSION}-x86.msi" \
    && WINE_MONO_URL="https://github.com/wine-mono/wine-mono/releases/download/wine-mono-${WINE_MONO_VERSION}/${WINE_MONO_MSI}" \
    && wget -qO "/tmp/${WINE_MONO_MSI}" "${WINE_MONO_URL}" \
    && wine msiexec /i "/tmp/${WINE_MONO_MSI}" \
    && rm "/tmp/${WINE_MONO_MSI}"

# Copy and set up entrypoint script
COPY --chown=$USERNAME:$USERNAME --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Set working directory
WORKDIR /home/$USERNAME

ENTRYPOINT ["/sbin/tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
