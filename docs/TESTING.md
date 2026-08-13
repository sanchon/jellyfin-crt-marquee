# Cómo se prueban los shaders

`test/test-shaders.ps1` valida que los shaders GLSL de `assets/shaders/` compilen y
rendericen correctamente, **sin abrir Jellyfin Media Player ni hacer clic en nada**.

```powershell
.\test\test-shaders.ps1
```

Requiere mpv standalone (no el mpv embebido en Jellyfin Media Player):

```powershell
winget install --id shinchiro.mpv -e
```

## Por qué existe este script (y por qué no es trivial)

Cuando se agregaron `crt-aperture.glsl` y `crt-hyllian.glsl`, fallaban en Jellyfin
Media Player de formas distintas cada vez (pantalla negra, luego azul, luego sin
efecto) y cada iteración de diagnóstico requería que un humano cerrara JMP, corriera
el launcher, reprodujera un video, y describiera lo que veía. Ese ciclo es lento y
impreciso. `test-shaders.ps1` reproduce el mismo pipeline de shaders de forma
automática y headless, leyendo directamente el log de compilación de mpv.

**Trampa importante que este script evita:** el primer intento de automatizar esto
usó `--vo=image` (el VO que escribe frames a archivos de imagen) para generar una
captura sin abrir una ventana. Resultó ser un **falso positivo**: `--vo=image` no
ejecuta el pipeline de shaders GPU en absoluto, así que `--glsl-shaders` se ignora
en silencio. Un shader con un identificador inexistente "pasaba" la prueba sin
ningún error, dando confianza falsa.

La forma correcta es usar `--vo=gpu` real (el mismo pipeline que usa Jellyfin Media
Player) y forzar una captura de pantalla real en cuanto arranca el primer frame,
usando un script Lua:

```lua
mp.register_event("playback-restart", function()
    mp.commandv("screenshot-to-file", os.getenv("MPV_TEST_OUT"), "video")
    mp.commandv("quit")
end)
```

Esto compila el shader de verdad, y si falla, mpv lo reporta en el log
(`vo/gpu/d3d11: shaderc output: ... error: ...` o similar).

## Autoverificación

Como ya nos mordió un falso positivo una vez, el script **no confía en sí mismo**:
antes de probar los shaders reales, genera un shader roto a propósito (referencia un
identificador que no existe) y confirma que el arnés SÍ lo detecta como error. Si esa
autoverificación falla, el script se detiene y avisa que los resultados no son
confiables, en vez de seguir e imprimir falsos "OK".

## Qué NO cubre

- No simula la interfaz de Jellyfin Media Player en sí (su capa Qt/WebEngine); prueba
  el motor de reproducción (mpv) con la misma configuración (`mpv.conf`, marco de TV,
  shaders) que genera `launcher.ps1`.
- No verifica automáticamente que el resultado visual sea "correcto" — guarda un PNG
  por shader en la carpeta temporal para inspección manual, pero el criterio de
  pase/falla es "compiló sin errores y generó una captura".
