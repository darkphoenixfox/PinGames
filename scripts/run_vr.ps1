# Runs PinGames in the VR cabinet layout (D-164) with OpenXR switched on.
# Start your OpenXR runtime first (SteamVR, or Quest Link / Air Link with the
# Meta runtime). Extra arguments are passed to the game, e.g.:
#   scripts/run_vr.ps1 --game=racer
# Without a headset it opens a desktop preview of the cabinet.
$ErrorActionPreference = 'Stop'
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = 'C:\Users\Phoenixfox\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe' }
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root '.godot'))) {
    & $godot --headless --path $root --import
}
& $godot --path $root --xr-mode on -- --layout=vr @args
exit $LASTEXITCODE
