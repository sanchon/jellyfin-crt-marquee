# Prueba automatizada de los shaders CRT usando el pipeline REAL de mpv (vo=gpu),
# sin necesidad de abrir Jellyfin Media Player ni hacer clic en nada.
#
# IMPORTANTE (leccion aprendida a las malas): --vo=image NO ejecuta el pipeline de
# shaders GPU -- glsl-shaders se ignora en silencio con ese VO, y un shader roto
# "pasa" la prueba sin ningun error. Hay que usar --vo=gpu real + tomar una
# captura de pantalla real (via script Lua en el evento playback-restart) para
# que la validacion sea genuina.
#
# Por eso este script se autoverifica primero: corre un shader roto A PROPOSITO
# y confirma que el arnes SI lo detecta, antes de confiar en el resultado "OK"
# de los shaders reales.
#
# Requiere mpv standalone (no el mpv embebido en Jellyfin Media Player):
#   winget install --id shinchiro.mpv -e
#
# Uso:
#   .\test\test-shaders.ps1
#   .\test\test-shaders.ps1 -MpvPath "C:\ruta\a\mpv.exe"

param(
    [string]$MpvPath,
    [string]$OutDir = (Join-Path $env:TEMP "jellyfin-crt-marquee-test")
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$assets = Join-Path $repoRoot "assets"

function Find-Mpv {
    param([string]$Hint)
    if ($Hint -and (Test-Path $Hint)) { return $Hint }
    $cmd = Get-Command mpv -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        "C:\Program Files\MPV Player\mpv.exe",
        (Join-Path $env:LOCALAPPDATA "Programs\mpv\mpv.exe")
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

$mpv = Find-Mpv -Hint $MpvPath
if (-not $mpv) {
    Write-Host "No encontre mpv.exe (standalone). Instalalo con:" -ForegroundColor Red
    Write-Host "  winget install --id shinchiro.mpv -e" -ForegroundColor Red
    Write-Host "o pasa la ruta con -MpvPath 'C:\ruta\a\mpv.exe'" -ForegroundColor Red
    exit 1
}
Write-Host "Usando mpv: $mpv" -ForegroundColor DarkGray

# --- Preparar una carpeta de config temporal con el marco de TV + shaders ---
# (no se usa la carpeta real de Jellyfin Media Player, para que esta prueba
# funcione en cualquier maquina que clone el repo, tenga o no JMP instalado)
New-Item -ItemType Directory -Force -Path $OutDir, "$OutDir\config\shaders", "$OutDir\config\images" | Out-Null
Copy-Item "$assets\shaders\*.glsl" "$OutDir\config\shaders\" -Force
Copy-Item "$assets\images\tv_bezel.png" "$OutDir\config\images\tv_bezel.png" -Force

$tvBezelPath = Join-Path $OutDir "config\images\tv_bezel.png"
$mpvConfContent = @"
external-file="$tvBezelPath"
lavfi-complex=[vid1]scale=474:364:force_original_aspect_ratio=decrease,pad=474:364:(ow-iw)/2:(oh-ih)/2:color=black[v];color=c=black:s=670x473[bg];[bg][vid2]overlay=0:0[tvopaque];[tvopaque][v]overlay=36:78,format=yuv420p[vo]
"@
Set-Content -Path "$OutDir\config\mpv.conf" -Value $mpvConfContent -Encoding utf8

# --- Script Lua: en cuanto arranca el primer frame real, toma captura y cierra ---
$luaScript = Join-Path $OutDir "screenshot-and-quit.lua"
@'
mp.register_event("playback-restart", function()
    mp.commandv("screenshot-to-file", os.getenv("MPV_TEST_OUT"), "video")
    mp.commandv("quit")
end)
'@ | Set-Content -Path $luaScript -Encoding utf8

function Test-Shader {
    param([string]$ShaderPath, [string]$OutPng, [switch]$UseConfigDir)

    $env:MPV_TEST_OUT = $OutPng
    if (Test-Path $OutPng) { Remove-Item $OutPng -Force }

    $mpvArgs = @(
        "av://lavfi:testsrc=size=1280x720:rate=1",
        "--glsl-shaders=$ShaderPath",
        "--vo=gpu",
        "--script=$luaScript",
        "--ao=null", "--force-window=yes", "--keep-open=no",
        "--msg-level=all=warn"
    )
    if ($UseConfigDir) { $mpvArgs = @("--config-dir=$OutDir\config") + $mpvArgs }

    $output = & $mpv @mpvArgs 2>&1 | Out-String
    $hasError = $output -match "error|ERROR"
    $gotPng = Test-Path $OutPng
    return @{ Output = $output; HasError = $hasError; GotPng = $gotPng; Ok = ($gotPng -and -not $hasError) }
}

# --- Autoverificacion: un shader roto A PROPOSITO debe FALLAR ---
Write-Host ""
Write-Host "=== Autoverificacion del arnes de pruebas ===" -ForegroundColor Cyan
$brokenShader = Join-Path $OutDir "broken-test.glsl"
@'
//!HOOK MAIN
//!DESC broken test shader (a proposito, para autoverificacion)
vec4 hook() {
    return vec4(ESTO_NO_EXISTE, 0.0, 0.0, 1.0);
}
'@ | Set-Content -Path $brokenShader -Encoding utf8

$selfCheck = Test-Shader -ShaderPath $brokenShader -OutPng (Join-Path $OutDir "broken.png")
if ($selfCheck.HasError) {
    Write-Host "OK: el arnes SI detecta un shader roto a proposito (como se espera)." -ForegroundColor Green
} else {
    Write-Host "ALERTA: el arnes NO detecto el shader roto -- los resultados de abajo NO son confiables." -ForegroundColor Red
    Write-Host $selfCheck.Output
    exit 2
}

# --- Probar cada shader real del repo ---
Write-Host ""
Write-Host "=== Probando shaders ===" -ForegroundColor Cyan
$results = @()
Get-ChildItem "$assets\shaders\*.glsl" | ForEach-Object {
    $name = $_.BaseName
    $shaderRef = "~~/shaders/$($_.Name)"
    $outPng = Join-Path $OutDir "$name.png"
    $r = Test-Shader -ShaderPath $shaderRef -OutPng $outPng -UseConfigDir
    $status = if ($r.Ok) { "OK" } else { "FALLO" }
    $color = if ($r.Ok) { "Green" } else { "Red" }
    Write-Host "  [$status] $name" -ForegroundColor $color
    if (-not $r.Ok) {
        ($r.Output -split "`n" | Where-Object { $_ -match "error|ERROR" } | Select-Object -First 10) | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
    }
    $results += [pscustomobject]@{ Shader = $name; OK = $r.Ok; Screenshot = $outPng }
}

Write-Host ""
Write-Host "Capturas guardadas en: $OutDir" -ForegroundColor DarkGray
$results | Format-Table -AutoSize

if ($results | Where-Object { -not $_.OK }) { exit 1 } else { exit 0 }
