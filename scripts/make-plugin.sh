#!/usr/bin/env bash
# Uso: make-plugin.sh <rootfs.tar.xz> <URL_pública_del_rootfs> <salida.sh>
# Genera el "plugin" de proot-distro: un .sh que le dice a proot-distro de dónde
# bajar el rootfs y cómo verificarlo (SHA-256).
set -euo pipefail
TARBALL="$1"; URL="$2"; OUT="$3"
SHA="$(sha256sum "$TARBALL" | cut -d' ' -f1)"
cat > "$OUT" <<PLUGIN
DISTRO_NAME="x86 on ARM64 (Debian + Box64 + Wine)"
DISTRO_COMMENT="Rootfs generado por GitHub Actions: Box64 + Wine amd64"
# El tar de 'docker export' NO tiene carpeta raíz -> no quitar niveles.
TARBALL_STRIP_OPT=0
TARBALL_URL['aarch64']="${URL}"
TARBALL_SHA256['aarch64']="${SHA}"
PLUGIN
echo "Plugin escrito en $OUT (sha256=$SHA)"
