#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
#  Arranca audio + pantalla + (opcional) GPU y lanza un programa x86.
#  Uso:  bash x86-start.sh programa.exe        (Windows)
#        bash x86-start.sh --linux ./binario   (Linux x86_64)
#        GPU=virgl bash x86-start.sh juego.exe (OpenGL acelerado por GPU)
# =============================================================================
set -u

# Audio: PulseAudio con socket TCP local (el rootfs lo ve en 127.0.0.1).
pulseaudio --start --exit-idle-time=-1 \
  --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" 2>/dev/null || true

# Pantalla: servidor X11 de Termux:X11 en :0 (abre la APP Termux:X11 para verlo).
pkill -f "termux-x11 :0" 2>/dev/null || true
termux-x11 :0 >/dev/null 2>&1 &
sleep 2

# GPU (OPCIONAL): virgl traduce OpenGL del rootfs -> GLES del driver Android
# (Xclipse 940 incluida). No es Vulkan; ver docs/GRAPHICS_XCLIPSE.md.
GPU_ENV=""
if [ "${GPU:-}" = "virgl" ]; then
  pkill -f virgl_test_server_android 2>/dev/null || true
  virgl_test_server_android >/dev/null 2>&1 &
  sleep 1
  GPU_ENV="GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.3 MESA_GLSL_VERSION_OVERRIDE=430"
fi

# --shared-tmp: comparte /tmp con Termux (sockets de X11 y virgl).
# --bind: expone tu almacenamiento interno en /mnt/sdcard dentro del rootfs.
exec proot-distro login x86arm --shared-tmp --bind /sdcard:/mnt/sdcard -- \
     env DISPLAY=:0 $GPU_ENV x86run "$@"
