# Guía de despliegue (GitHub → teléfono)

## 0. Requisitos
- Cuenta de GitHub. **Repositorio público** (los runners ARM64 `ubuntu-24.04-arm`
  son gratuitos sólo en repos públicos; en privados se cobran o hay que usar QEMU).
- Git instalado en tu PC.
- Teléfono Android con ~6 GB libres.

## 1. Subir el proyecto a GitHub
1. En github.com → **New repository** → nombre `arm-x86-container`, **Public**,
   SIN README/.gitignore/licencia (ya vienen en el proyecto).
2. En tu PC, dentro de la carpeta descomprimida:
   ```bash
   git init -b main
   git add .
   git update-index --chmod=+x scripts/x86run scripts/*.sh tests/smoke.sh
   git commit -m "Primer commit"
   git remote add origin https://github.com/TU_USUARIO/arm-x86-container.git
   git push -u origin main
   ```

## 2. Configurar GitHub (no omitir)
1. **Settings → Actions → General → Actions permissions**: "Allow all actions".
2. En la misma página, **Workflow permissions → Read and write permissions** → Save.
   (Sin esto la publicación de la Release falla con 403.)
3. Tras la primera publicación, en tu perfil → **Packages → arm-x86-container →
   Package settings → Change visibility → Public** (opcional; sólo si quieres
   `docker pull` anónimo. Para el teléfono NO hace falta: usa Releases).

## 3. Ejecutar el workflow
**Opción A – Release por tag (recomendada):**
```bash
git tag v0.1.0 && git push origin v0.1.0
```
**Opción B – Manual:** pestaña **Actions → Build & Release → Run workflow**;
rellena `release_tag` (p. ej. `v0.1.0`) para publicar. Aquí también puedes
elegir `box64_ref` y `wine_version`.

La primera ejecución tarda ~20-40 min (compila Box64, descarga Wine, comprime
el rootfs). Las siguientes usan caché. Al terminar, en **Releases** verás:
`box64-custom_*.deb`, `x86arm-rootfs-aarch64.tar.xz`, `x86arm.sh`, `SHA256SUMS.txt`.

## 4. Preparar el Samsung
1. Instala **Termux** desde **F-Droid** o desde GitHub Releases de `termux/termux-app`
   (la versión de Google Play está obsoleta y rota).
2. Instala la app **Termux:X11** (APK desde GitHub `termux/termux-x11`, release "nightly").
3. Ajustes → **Opciones de desarrollador** → activa **"Deshabilitar restricciones
   de procesos secundarios"** (Disable child process restrictions). Si no, Android 12+
   mata los procesos de Termux ("Process completed (signal 9)").
4. Ajustes → Aplicaciones → Termux y Termux:X11 → Batería → **Sin restricciones**.

## 5. Instalar en el teléfono (dentro de Termux)
```bash
pkg install -y curl
export REPO=TU_USUARIO/arm-x86-container
curl -fL https://raw.githubusercontent.com/$REPO/main/scripts/termux-install.sh -o i.sh
bash i.sh
```
Descarga ~300-500 MB. proot-distro verifica el SHA-256 del rootfs.

## 6. Ejecutar
1. Abre la app **Termux:X11** (pantalla negra = normal) y vuelve a Termux.
2. Prueba:
   ```bash
   bash ~/x86-start.sh --version                 # Box64 + Wine
   bash ~/x86-start.sh --init                    # crea el prefijo (1ª vez, minutos)
   bash ~/x86-start.sh notepad                   # app de Windows
   bash ~/x86-start.sh explorer /desktop=shell,1280x720   # escritorio virtual
   GPU=virgl bash ~/x86-start.sh /mnt/sdcard/Download/juego.exe
   ```
3. Binarios Linux x86_64: `bash ~/x86-start.sh --linux ./programa`.

## 7. Problemas típicos
| Síntoma | Causa / solución |
|---|---|
| Workflow 403 al publicar | Falta paso 2.2 (permisos de escritura) |
| `Queued` eterno | Repo privado sin minutos para runners ARM |
| `Tag 'vX' not found` en Box64 | Usa una rama/tag real (BOX64_REF no acepta SHA) |
| Wine: `could not load kernel32.dll` | Faltan libs :amd64; añade el paquete al Dockerfile y reconstruye |
| `signal 9` | Paso 4.3 sin hacer |
| Pantalla negra en X11 | Abre Termux:X11 ANTES de lanzar; usa `--shared-tmp` (ya incluido) |
| Muy lento en 3D | Normal sin GPU: ver `GRAPHICS_XCLIPSE.md` |

> **Estado:** el código no se ha podido ejecutar en este entorno (sin red ni
> runner ARM). La primera ejecución del workflow es la prueba real: si algún
> paso falla, el log de Actions indica cuál y se corrige en una línea.
