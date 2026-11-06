# syntax=docker/dockerfile:1.7
# =============================================================================
#  arm-x86-container  ·  Dockerfile multi-etapa
# =============================================================================
#  OBJETIVO: producir un rootfs Linux ARM64 (Debian) que contenga
#     1) Box64  -> traductor/emulador dinámico (dynarec) x86_64 -> ARM64.
#     2) Wine amd64 (binarios x86_64 oficiales de Kron4ek) -> ejecuta .exe de Windows.
#     3) Bibliotecas x86_64 mínimas (libc, X11, ALSA...) que Wine necesita.
#     4) Mesa software (llvmpipe/lavapipe) como renderizado de respaldo.
#
#  POR QUÉ ESTAS PIEZAS:
#   - Box64 (ptitSeb) NO es QEMU-user: genera código ARM64 nativo al vuelo y
#     reemplaza llamadas a libc/libX11/libGL por las versiones NATIVAS arm64
#     ("wrapping"). Es 5-10x más rápido que QEMU para juegos/apps. Este es el
#     motor del proyecto.
#   - Wine traduce la API de Windows -> Linux; como Wine es x86_64, corre
#     DENTRO de Box64. Alternativa a Wine: ejecutar sólo binarios Linux x86_64
#     con `box64 ./programa` (el wrapper lo soporta: `x86run --linux`).
#   - Base Debian bookworm: su mirror (deb.debian.org) sirve arm64 Y amd64 en
#     el mismo servidor, así `dpkg --add-architecture amd64` (multiarch)
#     funciona sin trucos. En Ubuntu habría que partir los repos (ports.ubuntu.com).
#
#  ETAPAS:  box64-builder -> deb-export (artefacto .deb)
#           wine-fetch
#           runtime (imagen final / rootfs)
# =============================================================================

ARG DEBIAN_RELEASE=bookworm

# -----------------------------------------------------------------------------
# ETAPA 1: compilar Box64 desde el código fuente
# -----------------------------------------------------------------------------
FROM debian:${DEBIAN_RELEASE}-slim AS box64-builder

ARG BOX64_REPO=https://github.com/ptitSeb/box64.git
# Rama o TAG (no SHA). Para builds reproducibles fija un tag, p.ej. v0.3.x
ARG BOX64_REF=main
ENV DEBIAN_FRONTEND=noninteractive

# git: clonar | cmake+build-essential: compilar | python3: lo usa Box64 para
# generar los wrappers | dpkg-dev: empaquetar el .deb
RUN apt-get update && apt-get install -y --no-install-recommends \
        git cmake build-essential python3 ca-certificates dpkg-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
# --depth 1: clon superficial (rápido). --branch acepta rama o tag.
RUN git clone --depth 1 --branch "${BOX64_REF}" "${BOX64_REPO}" box64

# Flags de CMake:
#  -DARM_DYNAREC=ON      -> activa el recompilador dinámico ARM64 (SIN esto Box64
#                           sólo interpreta y es ~10x más lento). IMPRESCINDIBLE.
#  -DCMAKE_BUILD_TYPE=RelWithDebInfo -> -O2 + símbolos (útil para reportar bugs).
# Exynos 2400 (Cortex-X4/A720/A520, ARMv9.2) es ARM64 estándar: no hay flag
# específico como -DSD8G2=ON (ése es para Snapdragon 8 Gen 2). Box64 detecta
# NEON/SVE en tiempo de ejecución.
RUN cmake -S box64 -B build \
        -DARM_DYNAREC=ON \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    && cmake --build build -j"$(nproc)"

# Instalar en un directorio temporal (/pkg) y construir un .deb a mano.
RUN DESTDIR=/pkg cmake --install build \
    && SHA="$(git -C box64 rev-parse --short HEAD)" \
    && mkdir -p /pkg/DEBIAN /out \
    && printf '%s\n' \
        "Package: box64-custom" \
        "Version: 0.0~git${SHA}" \
        "Architecture: arm64" \
        "Maintainer: arm-x86-container <noreply@example.com>" \
        "Description: Box64 (x86_64 -> ARM64 dynarec) compilado por GitHub Actions" \
        > /pkg/DEBIAN/control \
    && dpkg-deb --build --root-owner-group /pkg "/out/box64-custom_0.0-git${SHA}_arm64.deb"

# -----------------------------------------------------------------------------
# ETAPA 1b: sólo exporta el .deb (se usa con `--target deb-export --output`)
# -----------------------------------------------------------------------------
FROM scratch AS deb-export
COPY --from=box64-builder /out/ /

# -----------------------------------------------------------------------------
# ETAPA 2: descargar Wine x86_64 precompilado
# -----------------------------------------------------------------------------
FROM debian:${DEBIAN_RELEASE}-slim AS wine-fetch
ARG WINE_VERSION=9.22
# "amd64" = build x86_64 clásico (wine64). Otros sabores de Kron4ek:
# amd64-wow64 (un solo binario, 32+64 bit), x86 (32 bit).
ARG WINE_FLAVOR=amd64
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends curl xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Compilar Wine en CI son horas; reutilizamos builds de la comunidad (Kron4ek).
RUN curl -fsSL -o /tmp/wine.tar.xz \
      "https://github.com/Kron4ek/Wine-Builds/releases/download/${WINE_VERSION}/wine-${WINE_VERSION}-${WINE_FLAVOR}.tar.xz" \
    && mkdir -p /opt && tar -C /opt -xf /tmp/wine.tar.xz \
    && mv /opt/wine-* /opt/wine \
    && rm /tmp/wine.tar.xz

# -----------------------------------------------------------------------------
# ETAPA 3: imagen final = rootfs que se ejecuta en el teléfono
# -----------------------------------------------------------------------------
FROM debian:${DEBIAN_RELEASE}-slim AS runtime
ENV DEBIAN_FRONTEND=noninteractive

# Multiarch: permite instalar paquetes :amd64 junto a los arm64 nativos.
#  - Paquetes arm64 (nativos): Box64 los usa para "wrappear" llamadas a
#    libX11/libGL/libasound/SDL2... -> rendimiento cercano al nativo.
#  - Paquetes :amd64 : los necesita el propio Wine x86_64 (libc, libstdc++...),
#    que Box64 carga y traduce.
RUN dpkg --add-architecture amd64 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget xz-utils unzip cabextract procps nano \
      x11-utils x11-xserver-utils pulseaudio-utils fonts-liberation \
      libx11-6 libxext6 libxrandr2 libxcursor1 libxi6 libxfixes3 libxrender1 \
      libxcomposite1 libxinerama1 libxxf86vm1 libfreetype6 libfontconfig1 \
      libasound2 libpulse0 libsdl2-2.0-0 libgl1 libgl1-mesa-dri libglx-mesa0 \
      mesa-vulkan-drivers vulkan-tools \
      libc6:amd64 libstdc++6:amd64 libgcc-s1:amd64 zlib1g:amd64 \
      libx11-6:amd64 libxext6:amd64 libxrandr2:amd64 libxcursor1:amd64 \
      libxi6:amd64 libxfixes3:amd64 libxrender1:amd64 libxcomposite1:amd64 \
      libxinerama1:amd64 libxxf86vm1:amd64 libxkbcommon0:amd64 \
      libfreetype6:amd64 libfontconfig1:amd64 libasound2:amd64 libpulse0:amd64 \
      libgnutls30:amd64 libdbus-1-3:amd64 libpng16-16:amd64 \
      libgl1:amd64 libvulkan1:amd64 libsdl2-2.0-0:amd64 \
 && rm -rf /var/lib/apt/lists/*
# (mesa-vulkan-drivers = lavapipe, Vulkan por CPU; libgl1-mesa-dri = llvmpipe y
#  el driver virgl para aceleración GPU vía Android, ver docs/GRAPHICS_XCLIPSE.md)

# Instalar NUESTRO box64 (.deb construido en la etapa 1).
COPY --from=box64-builder /out/*.deb /tmp/
RUN apt-get update && apt-get install -y /tmp/box64-custom_*.deb \
    && rm -rf /tmp/*.deb /var/lib/apt/lists/*

# Wine x86_64
COPY --from=wine-fetch /opt/wine /opt/wine

# Perfil de rendimiento de Box64 (sobrescribe el del .deb) y wrapper de uso.
COPY config/box64.box64rc /etc/box64.box64rc
COPY scripts/x86run /usr/local/bin/x86run
RUN chmod 0755 /usr/local/bin/x86run

# Variables que proot-distro NO hereda de ENV; por eso también van a profile.d.
RUN printf '%s\n' \
      'export DISPLAY=${DISPLAY:-:0}' \
      'export PULSE_SERVER=${PULSE_SERVER:-127.0.0.1}' \
      'export WINEDEBUG=${WINEDEBUG:--all}' \
      'export PATH=$PATH:/opt/wine/bin' \
      > /etc/profile.d/x86env.sh

CMD ["/bin/bash", "-l"]
