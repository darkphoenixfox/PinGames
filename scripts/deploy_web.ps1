# Builds the browser version (D-173) and deploys it to the NAS web server as a
# subpath: https://web.phoenixfox.net/pingames/ (LAN: http://192.168.1.150:8086/pingames/).
# The HeroAR stack's NGINX serves K:\heroar\www statically; the HeroAR client
# deploy (robocopy /E) adds files but never deletes, so www\pingames survives it.
# No server restart needed. Non-threaded build: no COOP/COEP headers required.
$ErrorActionPreference = 'Stop'
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = 'C:\Users\Phoenixfox\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe' }
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'exports\web'
New-Item -ItemType Directory -Force $out | Out-Null
Remove-Item (Join-Path $out 'index.*') -ErrorAction SilentlyContinue
# Godot 4.7 sometimes keeps running after a headless export: wait for the
# output files to stop growing, then stop it.
$p = Start-Process -FilePath $godot -NoNewWindow -PassThru -ArgumentList @(
    '--headless', '--path', "`"$root`"", '--export-release', 'Web', "`"$(Join-Path $out 'index.html')`"")
$pck = Join-Path $out 'index.pck'
$last = -1; $stable = 0
for ($i = 0; $i -lt 300 -and -not $p.HasExited; $i++) {
    Start-Sleep -Seconds 2
    if ((Test-Path $pck) -and (Test-Path (Join-Path $out 'index.wasm')) -and (Test-Path (Join-Path $out 'index.html'))) {
        $len = (Get-Item $pck).Length
        if ($len -eq $last) { $stable++ } else { $stable = 0; $last = $len }
        if ($stable -ge 4) { break }
    }
}
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
if (-not (Test-Path $pck)) { Write-Error 'Web export failed: no index.pck'; exit 1 }
# Pre-compressed copies: the NAS NGINX serves them with gzip_static (HeroAR DEC-0275).
foreach ($name in @('index.wasm', 'index.pck', 'index.js')) {
    $src = Join-Path $out $name
    $in = [System.IO.File]::OpenRead($src)
    $outStream = [System.IO.File]::Create("$src.gz")
    $gz = New-Object System.IO.Compression.GZipStream($outStream, [System.IO.Compression.CompressionLevel]::Optimal)
    $in.CopyTo($gz)
    $gz.Dispose(); $outStream.Dispose(); $in.Dispose()
}
$dest = 'K:\heroar\www\pingames'
New-Item -ItemType Directory -Force $dest | Out-Null
robocopy $out $dest /MIR /R:1 /W:1 | Out-Null
if ($LASTEXITCODE -ge 8) { exit $LASTEXITCODE }
Write-Host "Deployed: https://web.phoenixfox.net/pingames/"
exit 0
