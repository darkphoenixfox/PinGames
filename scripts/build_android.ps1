# Builds the flat-screen Android APK (D-180): the single-canvas layout of the
# browser build (TABLE + BACKGLASS + DMD, touch buttons at the sides), no XR.
# Gradle build, arm64, debug-signed with Godot's debug keystore - for sideloading.
# Needs: Godot 4.7.2 Android export templates, Android SDK + JDK 17 in Godot's
# editor settings (as for build_quest.ps1).
# Output: exports\PinGames-android.apk   Install: adb install -r exports\PinGames-android.apk
# -Deploy also publishes it to https://web.phoenixfox.net/pingames-apk/PinGames-android.apk
# (K:\heroar\www\pingames-apk, D-181; its own folder: the web deploy mirrors www\pingames).
param([switch]$Deploy)
$ErrorActionPreference = 'Stop'
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = 'C:\Users\Phoenixfox\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe' }
$root = Split-Path -Parent $PSScriptRoot
$apk = Join-Path $root 'exports\PinGames-android.apk'
New-Item -ItemType Directory -Force (Join-Path $root 'exports') | Out-Null
Remove-Item $apk -ErrorAction SilentlyContinue
$args_ = @('--headless', '--path', "`"$root`"")
if (-not (Test-Path (Join-Path $root 'android\build'))) { $args_ += '--install-android-build-template' }
$args_ += @('--export-debug', 'Android', "`"$apk`"")
# Godot 4.7 sometimes keeps running after a headless export: wait for the APK
# to stop growing, then stop it.
$p = Start-Process -FilePath $godot -NoNewWindow -PassThru -ArgumentList $args_
$last = -1; $stable = 0
for ($i = 0; $i -lt 600 -and -not $p.HasExited; $i++) {
    Start-Sleep -Seconds 2
    if (Test-Path $apk) {
        $len = (Get-Item $apk).Length
        if ($len -eq $last) { $stable++ } else { $stable = 0; $last = $len }
        if ($stable -ge 5) { break }
    }
}
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
if (-not (Test-Path $apk)) { Write-Error 'Android export failed: no APK'; exit 1 }
Write-Host "Built: $apk"
if ($Deploy) {
    $dest = 'K:\heroar\www\pingames-apk'
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item $apk (Join-Path $dest 'PinGames-android.apk') -Force
    Write-Host "Deployed: https://web.phoenixfox.net/pingames-apk/PinGames-android.apk"
}
exit 0
