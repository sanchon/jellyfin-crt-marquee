# Jellyfin CRT Marquee

Instalador de shaders CRT + marco/marquee de TV vintage para [Jellyfin Media Player](https://github.com/jellyfin/jellyfin-media-player) (el cliente de escritorio basado en mpv).

Convierte la reproducción de video en Jellyfin en algo así:

- El video queda insertado dentro del hueco de pantalla de una TV CRT antigua (imagen con marco).
- El área de pantalla aplica un shader CRT real (curvatura, scanlines, máscara de fósforo RGB) — el marco/carcasa de la TV se queda intacto, sin el efecto encima.
- Podés elegir entre 3 shaders distintos o desactivarlo.

## Instalación

1. Cierra Jellyfin Media Player si está abierto.
2. Doble clic en `Instalar shader CRT.bat`.
3. El script:
   - Copia los shaders y la imagen del marco a la carpeta de configuración de JMP (`%LOCALAPPDATA%\jellyfinmediaplayer`).
   - Activa `useOpenGL` en `jellyfinmediaplayer.conf` (necesario, si no el video se ve en pantalla negra — JMP usa ANGLE por defecto, que no soporta bien shaders multi-pasada).
   - Te deja elegir el shader: **CRT Lottes**, **CRT Aperture**, **CRT Hyllian**, o ninguno.
4. Abre Jellyfin Media Player normalmente.

Para cambiar de shader más adelante, repite los pasos (correr el instalador de nuevo es seguro, no duplica nada).

Es portable: podés copiar toda la carpeta a otro PC con Jellyfin Media Player instalado, no depende de ningún usuario de Windows en particular.

## Cómo funciona (resumen técnico)

- `mpv.conf` usa `--lavfi-complex` para componer el video dentro del hueco de pantalla del PNG del marco (`external-file` en vez del filtro `movie=`, porque `movie=` no soporta bien rutas de Windows con letra de unidad — bug conocido de ffmpeg/mpv).
- El hueco de pantalla del PNG se detectó analizando el canal alfa (semi-transparente) con un script de flood-fill: `X=36 Y=78 W=474 H=364` sobre una imagen de `670x473`.
- Cada shader GLSL fue modificado para confinar el efecto CRT (curvatura, scanlines, máscara) solo a ese rectángulo — fuera de él, el pixel pasa sin procesar, para no aplicar el efecto sobre la carcasa/plástico de la TV.
- Jellyfin Media Player **no** permite cambiar de shader en caliente con atajos de teclado: su capa de interfaz (`inputmaps/*.json`) intercepta todas las teclas antes de que lleguen a mpv. Por eso el cambio de shader se hace reinstalando/reconfigurando, no con una tecla dentro de la app.

## Créditos y licencias

- Los shaders `crt-lottes.glsl`, `crt-aperture.glsl` y `crt-hyllian.glsl` son adaptaciones de shaders CRT portados a formato mpv por el proyecto [hhirtz/mpv-retro-shaders](https://github.com/hhirtz/mpv-retro-shaders) (usando la herramienta `mpv-libretro`) a partir de shaders originales de [libretro/glsl-shaders](https://github.com/libretro/glsl-shaders), creados originalmente por Timothy Lottes (crt-lottes), Hyllian (crt-hyllian) y otros colaboradores de la comunidad libretro/RetroArch. Cada shader conserva su encabezado de copyright original cuando estaba disponible en la fuente. Ver los repositorios mencionados para el detalle de licencia de cada shader.
- La imagen `tv_bezel.png` fue provista por el autor de este repositorio.
- El código propio de este repositorio (`install.ps1`, el `.bat`, los cambios de recorte de área de pantalla en los shaders, `mpv.conf`) se distribuye bajo licencia MIT (ver `LICENSE`).
