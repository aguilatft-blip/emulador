#!/usr/bin/env bash
# Se ejecuta DENTRO del contenedor en CI. Si algo falla, el workflow falla
# ANTES de publicar la release (evita publicar un rootfs roto).
set -euo pipefail
echo "== Box64 =="            ; box64 --version
echo "== Perfil Box64 =="     ; test -s /etc/box64.box64rc && echo OK
echo "== Wine x86_64 bajo Box64 =="
# Ejecuta un binario x86_64 REAL (wine64) traducido a ARM64: valida
# Box64 + libs amd64 + Wine de una sola vez.
x86run --version
echo "== Todo correcto =="
