#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
#  Instalador para el TELÉFONO (ejecutar dentro de Termux).
#  Uso:  REPO=usuario/repositorio bash termux-install.sh
#  Hace: instala proot-distro + Termux:X11 (servidor gráfico) + PulseAudio
#        (+ virglrenderer para GPU), descarga el plugin de tu Release e
#        instala el rootfs como la distro "x86arm".
# =============================================================================
set -euo pipefail
: "${REPO:?Define REPO=usuario/repositorio (el de GitHub)}"

pkg update -y && pkg upgrade -y
pkg install -y x11-repo                       # repo con paquetes gráficos
# proot-distro: "chroot" sin root. termux-x11-nightly: servidor X (lado Termux).
# pulseaudio: audio. virglrenderer-android: OpenGL acelerado vía GLES de Android.
pkg install -y proot-distro termux-x11-nightly pulseaudio virglrenderer-android wget curl

# 'latest/download' apunta siempre a la última Release que tenga ese asset.
mkdir -p "$PREFIX/etc/proot-distro"
curl -fL "https://github.com/${REPO}/releases/latest/download/x86arm.sh" \
     -o "$PREFIX/etc/proot-distro/x86arm.sh"

proot-distro install x86arm                   # descarga + verifica SHA-256 + extrae
curl -fL "https://raw.githubusercontent.com/${REPO}/main/scripts/termux-start.sh" \
     -o "$HOME/x86-start.sh"
echo "Listo. Abre la app Termux:X11 y ejecuta:  bash ~/x86-start.sh app.exe"
