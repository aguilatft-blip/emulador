# Gráficos en Exynos 2400 / Xclipse 940

## La limitación real
- Xclipse 940 es una GPU derivada de AMD RDNA 3, pero en Android sólo existe
  el **driver propietario de Samsung** (Vulkan/GLES), compilado contra **bionic**.
- El rootfs de este proyecto es **glibc**: no puede cargar ese driver directamente.
- **Turnip** (Mesa) es sólo para Adreno; **PanVK/Panfrost** sólo para Mali.
  No hay driver Mesa abierto para Xclipse en Android.

## Qué hace este proyecto
| Ruta | Estado | Notas |
|---|---|---|
| **llvmpipe / lavapipe** (CPU) | Incluida, funciona siempre | Lenta; válida para apps 2D y juegos antiguos |
| **virgl** (`GPU=virgl`) | Incluida | OpenGL del rootfs → GLES del driver Samsung. Acelera WineD3D (DX9/10/11 vía OpenGL). **No es Vulkan** |
| **Vulkan nativo (DXVK)** | NO incluida | Requiere un puente a Vulkan de Android (estilo "Vortek" de Winlator) |

## Fase 2 (si necesitas Vulkan/DXVK real)
El puente Vulkan→driver Android necesita un componente **bionic dentro de una
app APK** (JNI/NDK). Camino realista: partir de un fork open source tipo
Winlator, y automatizar su compilación con Gradle + NDK en GitHub Actions
(`./gradlew assembleRelease` + subida del `.apk` a Releases). Es un proyecto
distinto en tamaño; se puede añadir a este repositorio como segundo workflow.
