# Runs PinGames. Extra arguments are passed to the game, e.g.:
#   scripts/run.ps1 --layout=windowed --game=breakout
# Godot binary: $env:GODOT_BIN, else the default path below.
$ErrorActionPreference = 'Stop'
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = 'C:\Users\Phoenixfox\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe' }
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root '.godot'))) {
    & $godot --headless --path $root --import
}
& $godot --path $root -- @args
exit $LASTEXITCODE
