# Builds the Quest APK (D-170): the VR cabinet layout, OpenXR via the Godot
# OpenXR Vendors plugin (Meta loader), Gradle build, arm64, debug-signed with
# Godot's debug keystore - for sideloading.
# Needs: Godot 4.7.2 Android export templates in %APPDATA%\Godot\export_templates\4.7.2.stable,
# Android SDK + JDK 17 set in Godot's editor settings (export/android/*).
# Output: exports\PinGames-quest.apk   Install: adb install -r exports\PinGames-quest.apk
$ErrorActionPreference = 'Stop'
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = 'C:\Users\Phoenixfox\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe' }
$root = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force (Join-Path $root 'exports') | Out-Null
$extra = @()
if (-not (Test-Path (Join-Path $root 'android\build'))) { $extra += '--install-android-build-template' }
& $godot --headless --path $root @extra --export-debug "Quest" (Join-Path $root 'exports\PinGames-quest.apk')
exit $LASTEXITCODE
