# arm-x86-container

Entorno ligero para ejecutar **binarios x86/x86_64 (Linux y Windows) en ARM64**
(Android moderno, p. ej. Samsung Galaxy S24 / Exynos 2400), construido
íntegramente con **GitHub Actions**.

| Pieza | Función |
|---|---|
| **Box64** (compilado en CI) | Traducción dinámica x86_64 → ARM64 |
| **Wine amd64** | Ejecuta `.exe` de Windows sobre Box64 |
| **Debian bookworm arm64 + multiarch** | Rootfs con libs nativas y libs x86_64 |
| **Termux + proot-distro + Termux:X11** | Ejecución en Android sin root |
| **GitHub Releases / GHCR** | Distribución de `.deb`, rootfs e imagen OCI |

Guía completa: [`docs/DEPLOY_ES.md`](docs/DEPLOY_ES.md) ·
Gráficos/Xclipse: [`docs/GRAPHICS_XCLIPSE.md`](docs/GRAPHICS_XCLIPSE.md)
