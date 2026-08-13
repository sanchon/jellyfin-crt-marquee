# Instalador + selector + lanzador de shader CRT / marquee de TV para Jellyfin Media Player.
# Se puede correr las veces que quieras: reinstala los assets, te deja re-elegir shader,
# y al final cierra (si estaba abierto) y vuelve a abrir Jellyfin Media Player.

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$assets    = Join-Path $scriptDir "assets"
$jmpConfig = Join-Path $env:LOCALAPPDATA "jellyfinmediaplayer"

# Soporte de mando (XInput, mandos tipo Xbox) para navegar el menu de seleccion.
# xinput9_1_0.dll viene incluida en Windows desde Vista, no requiere instalar nada.
Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public struct XINPUT_GAMEPAD {
    public ushort wButtons;
    public byte bLeftTrigger;
    public byte bRightTrigger;
    public short sThumbLX;
    public short sThumbLY;
    public short sThumbRX;
    public short sThumbRY;
}
public struct XINPUT_STATE {
    public uint dwPacketNumber;
    public XINPUT_GAMEPAD Gamepad;
}
public static class XInput {
    [DllImport("xinput9_1_0.dll")]
    public static extern uint XInputGetState(uint dwUserIndex, ref XINPUT_STATE pState);
}
"@ -ErrorAction SilentlyContinue

$script:XINPUT_DPAD_UP   = 0x0001
$script:XINPUT_DPAD_DOWN = 0x0002
$script:XINPUT_A         = 0x1000

function Get-GamepadState {
    # Devuelve el estado del primer mando conectado (indices 0-3), o $null si no hay ninguno.
    try {
        for ($i = 0; $i -lt 4; $i++) {
            $state = New-Object XINPUT_STATE
            if ([XInput]::XInputGetState($i, [ref]$state) -eq 0) { return $state }
        }
    } catch {
        # xinput9_1_0.dll no disponible o algun otro fallo: seguimos solo con teclado.
    }
    return $null
}

function Select-MenuOption {
    # Menu interactivo: flechas/D-pad + Enter/boton A para navegar y confirmar,
    # o escribir el numero directamente. Funciona con o sin mando conectado.
    param([System.Collections.Specialized.OrderedDictionary]$Options)

    $keys = @($Options.Keys)
    $selectedIndex = 0
    $prevButtons = 0
    $lastRender = -1

    Write-Host ""
    Write-Host "Flechas o D-pad del mando + Enter/boton A para elegir, o escribe el numero." -ForegroundColor DarkGray
    Write-Host ""
    $menuTop = [Console]::CursorTop

    while ($true) {
        if ($selectedIndex -ne $lastRender) {
            [Console]::SetCursorPosition(0, $menuTop)
            for ($i = 0; $i -lt $keys.Count; $i++) {
                $k = $keys[$i]
                $line = "  $k) $($Options[$k].Name)    "
                if ($i -eq $selectedIndex) {
                    Write-Host ("> $k) $($Options[$k].Name)    ") -ForegroundColor Black -BackgroundColor Cyan
                } else {
                    Write-Host $line
                }
            }
            $lastRender = $selectedIndex
        }

        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -ge [ConsoleKey]::D1 -and $key.Key -le [ConsoleKey]::D9) {
                $typed = [string]([int]$key.Key - [int][ConsoleKey]::D0)
                if ($Options.Contains($typed)) { Write-Host ""; return $typed }
            } elseif ($key.Key -eq [ConsoleKey]::UpArrow) {
                $selectedIndex = ($selectedIndex - 1 + $keys.Count) % $keys.Count
            } elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
                $selectedIndex = ($selectedIndex + 1) % $keys.Count
            } elseif ($key.Key -eq [ConsoleKey]::Enter) {
                Write-Host ""
                return $keys[$selectedIndex]
            }
        }

        $state = Get-GamepadState
        if ($state) {
            $buttons = $state.Gamepad.wButtons
            $pressed = $buttons -band (-bnot $prevButtons)
            if ($pressed -band $script:XINPUT_DPAD_UP)   { $selectedIndex = ($selectedIndex - 1 + $keys.Count) % $keys.Count }
            if ($pressed -band $script:XINPUT_DPAD_DOWN) { $selectedIndex = ($selectedIndex + 1) % $keys.Count }
            if ($pressed -band $script:XINPUT_A) { Write-Host ""; return $keys[$selectedIndex] }
            $prevButtons = $buttons
        } else {
            $prevButtons = 0
        }

        Start-Sleep -Milliseconds 50
    }
}

function Find-JMPExecutable {
    $candidates = @(
        (Join-Path $env:ProgramFiles "Jellyfin\Jellyfin Media Player\JellyfinMediaPlayer.exe")
    )
    # $env:ProgramFiles se redirige a "Program Files (x86)" cuando el proceso de
    # PowerShell que ejecuta esto es de 32 bits (redireccion de WOW64), aunque JMP
    # este instalado en la ruta real de 64 bits. $env:ProgramW6432 siempre apunta
    # a la ruta real de 64 bits sin importar la arquitectura del proceso.
    if ($env:ProgramW6432) {
        $candidates += (Join-Path $env:ProgramW6432 "Jellyfin\Jellyfin Media Player\JellyfinMediaPlayer.exe")
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} "Jellyfin\Jellyfin Media Player\JellyfinMediaPlayer.exe")
    }
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    $proc = Get-Process -Name "JellyfinMediaPlayer" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc -and $proc.Path) { return $proc.Path }
    return $null
}

function Wait-AnyKeyOrButton {
    # Espera cualquier tecla o cualquier boton del mando (no solo Enter).
    param([string]$Message = "Presiona cualquier tecla o boton del mando para salir...")
    Write-Host $Message
    while ($true) {
        if ([Console]::KeyAvailable) {
            [Console]::ReadKey($true) | Out-Null
            return
        }
        $state = Get-GamepadState
        if ($state -and $state.Gamepad.wButtons -ne 0) { return }
        Start-Sleep -Milliseconds 50
    }
}

Write-Host "=== Instalador / lanzador de shader CRT para Jellyfin Media Player ===" -ForegroundColor Cyan
Write-Host ""

# 1) Cerrar JMP si esta abierto (ANTES de tocar la config: si lo dejamos abierto y
#    lo cierra el usuario despues, JMP reescribe jellyfinmediaplayer.conf con lo que
#    tenia en memoria y perderiamos el cambio de useOpenGL).
$exePath = Find-JMPExecutable
$running = Get-Process -Name "JellyfinMediaPlayer" -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "Cerrando Jellyfin Media Player..." -ForegroundColor Cyan
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# 2) Crear carpetas de destino y copiar assets
New-Item -ItemType Directory -Force -Path $jmpConfig, "$jmpConfig\shaders", "$jmpConfig\images" | Out-Null
Copy-Item "$assets\shaders\*.glsl" "$jmpConfig\shaders\" -Force
Copy-Item "$assets\images\tv_frame.png" "$jmpConfig\images\tv_frame.png" -Force
Write-Host "Shaders e imagen del marco instalados en: $jmpConfig" -ForegroundColor Green

# 3) Activar useOpenGL en jellyfinmediaplayer.conf (necesario o el shader se ve en pantalla negra)
$jsonPath = Join-Path $jmpConfig "jellyfinmediaplayer.conf"
if (Test-Path $jsonPath) {
    $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
    if (-not $json.sections.main) {
        Write-Host "AVISO: jellyfinmediaplayer.conf no tiene seccion 'main', no se pudo activar useOpenGL." -ForegroundColor Yellow
    } else {
        if ($null -eq $json.sections.main.useOpenGL) {
            $json.sections.main | Add-Member -NotePropertyName useOpenGL -NotePropertyValue $true -Force
        } else {
            $json.sections.main.useOpenGL = $true
        }
        ($json | ConvertTo-Json -Depth 10) | Set-Content -Path $jsonPath -Encoding utf8
        Write-Host "useOpenGL activado en jellyfinmediaplayer.conf." -ForegroundColor Green
    }
} else {
    Write-Host "AVISO: no existe jellyfinmediaplayer.conf todavia." -ForegroundColor Yellow
    Write-Host "Abre Jellyfin Media Player una vez, conectalo a tu servidor, cierralo, y vuelve a correr este instalador." -ForegroundColor Yellow
}

# 4) Elegir shader / marco
$options = [ordered]@{
    "1" = @{ Name = "CRT Lottes (marco de TV + curvatura + scanlines + mascara RGB)"; File = "crt-lottes.glsl";   Marquee = $true }
    "2" = @{ Name = "CRT Aperture (marco de TV + rejilla nitida, mas ligero)";        File = "crt-aperture.glsl"; Marquee = $true }
    "3" = @{ Name = "CRT Hyllian (marco de TV + scanlines + mascara balanceada)";     File = "crt-hyllian.glsl";  Marquee = $true }
    "4" = @{ Name = "Solo marco de TV (sin efecto CRT)";                              File = $null;               Marquee = $true }
    "5" = @{ Name = "Desactivar todo (Jellyfin normal, sin marco ni shader)";         File = $null;               Marquee = $false }
}
Write-Host ""
Write-Host "=== Elige el shader / marco CRT ===" -ForegroundColor Cyan
$choice = Select-MenuOption -Options $options
if (-not $options.Contains($choice)) {
    Write-Host "Opcion invalida, uso CRT Lottes por defecto." -ForegroundColor Yellow
    $choice = "1"
}
$selected = $options[$choice]

# 5) Generar mpv.conf (marco de TV + shader elegido, o vacio si se desactivo todo)
if ($selected.Marquee) {
    $tvBezelPath = Join-Path $jmpConfig "images\tv_frame.png"
    $glslLine = if ($selected.File) { "glsl-shaders=`"~~/shaders/$($selected.File)`"" } else { "# glsl-shaders desactivado (sin efecto CRT)" }

    $mpvConfContent = @"
# Generado por el instalador de shader CRT (JellyfinCRT-Installer).
# Marquee de TV CRT: inserta el video dentro del hueco de pantalla de tv_frame.png (1275x832),
# rellenando el area y dejando barras negras si el aspecto no coincide.
# Se usa --external-file en vez de movie=... dentro del grafo porque el filtro movie
# no soporta bien rutas de Windows con letra de unidad (bug conocido de ffmpeg/mpv).
external-file="$tvBezelPath"
# Orden de composicion: negro -> video -> marco ENCIMA. El PNG del marco tiene el hueco
# de pantalla realmente transparente, asi que el video asoma por el y las esquinas
# redondeadas del tubo recortan la imagen. El video se dibuja 826x618 en 108,114: un par
# de pixeles mas grande que el hueco (109,115 822x615) para que no quede junta visible.
lavfi-complex=[vid1]scale=826:618:force_original_aspect_ratio=decrease,pad=826:618:(ow-iw)/2:(oh-ih)/2:color=black[v];color=c=black:s=1275x832[bg];[bg][v]overlay=108:114[conVideo];[conVideo][vid2]overlay=0:0,format=yuv420p[vo]

# Shader CRT activo (confinado al hueco de pantalla del marco)
$glslLine
"@
} else {
    $mpvConfContent = @"
# Generado por el instalador de shader CRT (JellyfinCRT-Installer).
# Todo desactivado: sin marco de TV, sin shader CRT. Jellyfin Media Player
# reproduce normal. Vuelve a correr el launcher para reactivarlo.
"@
}

Set-Content -Path (Join-Path $jmpConfig "mpv.conf") -Value $mpvConfContent -Encoding utf8

# input.conf: dejamos la nota de que los atajos no funcionan en JMP
$inputConfContent = @"
# Los atajos de teclado personalizados aqui NO funcionan en Jellyfin Media Player:
# la interfaz de JMP (inputmaps/*.json) intercepta todas las teclas antes de que
# lleguen a mpv. Para cambiar el shader CRT vuelve a correr launcher.ps1
# (o "Jellyfin CRT Launcher.bat") -- cierra y reabre JMP automaticamente.
"@
Set-Content -Path (Join-Path $jmpConfig "input.conf") -Value $inputConfContent -Encoding utf8

Write-Host ""
Write-Host "Listo: $($selected.Name)" -ForegroundColor Green

# 6) Abrir Jellyfin Media Player
if ($exePath) {
    Write-Host "Abriendo Jellyfin Media Player..." -ForegroundColor Green
    Start-Process -FilePath $exePath
} else {
    Write-Host "No pude encontrar JellyfinMediaPlayer.exe automaticamente. Abrelo manualmente." -ForegroundColor Yellow
    Wait-AnyKeyOrButton
}
