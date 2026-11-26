# Builds the LeiaSR GDExtension (D-418) into native/bin/leiasr.windows.x86_64.dll.
# Needs the VS 2022 Build Tools (C++), and the LeiaSR SDK (LEIASR_SDKROOT, or
# C:\Users\Phoenixfox\Dev\LeiaSDK). Fetches godot-cpp at a pinned commit into
# native/third_party (git-ignored). The built DLL is committed (Git LFS), so
# only rebuild after changing native/leiasr/.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$cpp = Join-Path $root 'native\third_party\godot-cpp'
$pin = '27d9dd23c83871e0619fca5dc2cddfbfd69e926a'   # godot-cpp 4.5 branch
if (-not (Test-Path $cpp)) {
    git clone --filter=blob:none https://github.com/godotengine/godot-cpp.git $cpp
}
git -C $cpp checkout -q $pin
# CMake writes notes to stderr; don't treat them as failures.
$ErrorActionPreference = 'Continue'
$vs = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools'
$cmake = Join-Path $vs 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
$build = Join-Path $root 'native\build'
& $cmake -S (Join-Path $root 'native\leiasr') -B $build -G 'Visual Studio 17 2022' -A x64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $cmake --build $build --config Release --target leiasr -- /m /v:minimal
exit $LASTEXITCODE
