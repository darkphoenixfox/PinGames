# Imports the project (first run) and runs the headless smoke tests.
$ErrorActionPreference = 'Stop'
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = 'C:\Users\Phoenixfox\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe' }
$root = Split-Path -Parent $PSScriptRoot
& $godot --headless --path $root --import
& $godot --headless --path $root --script res://tests/run_tests.gd
exit $LASTEXITCODE
