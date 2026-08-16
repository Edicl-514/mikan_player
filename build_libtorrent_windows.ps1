param(
    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$Configuration = "Release",
    [string]$Triplet = "x64-windows",
    [string]$VcpkgRoot = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\vcpkg"
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$vcpkgManifest = Join-Path $repoRoot "vcpkg.json"

function Get-UsableVcpkgRoot {
    param([string]$PreferredRoot)

    $preferredToolchain = Join-Path $PreferredRoot "scripts\buildsystems\vcpkg.cmake"
    $preferredOpenSslPort = Join-Path $PreferredRoot "ports\openssl"
    $preferredBoostPort = Join-Path $PreferredRoot "ports\boost-headers"
    if ((Test-Path $preferredToolchain) -and
        (Test-Path $preferredOpenSslPort) -and
        (Test-Path $preferredBoostPort)) {
        return $PreferredRoot
    }

    Write-Host "VS bundled vcpkg has no local ports tree; using build\tools\vcpkg instead."
    $localRoot = Join-Path $repoRoot "build\tools\vcpkg"
    if (!(Test-Path (Join-Path $localRoot ".git"))) {
        New-Item -ItemType Directory -Force -Path (Split-Path $localRoot -Parent) | Out-Null
        git clone https://github.com/microsoft/vcpkg.git $localRoot 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clone vcpkg with exit code $LASTEXITCODE"
        }
    }

    if (Test-Path $vcpkgManifest) {
        $manifest = Get-Content $vcpkgManifest -Raw | ConvertFrom-Json
        $baseline = $manifest.'builtin-baseline'
        if ($baseline) {
            $currentBaseline = (& git -C $localRoot rev-parse HEAD).Trim()
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to read current vcpkg revision with exit code $LASTEXITCODE"
            }
            if ($currentBaseline -ne $baseline) {
                git -C $localRoot checkout --quiet $baseline
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to checkout vcpkg baseline with exit code $LASTEXITCODE"
                }
            }
        }
    }

    $localExe = Join-Path $localRoot "vcpkg.exe"
    if (!(Test-Path $localExe)) {
        & (Join-Path $localRoot "bootstrap-vcpkg.bat") -disableMetrics 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to bootstrap vcpkg with exit code $LASTEXITCODE"
        }
    }

    return $localRoot
}

$resolvedVcpkgRoot = Get-UsableVcpkgRoot -PreferredRoot $VcpkgRoot
$vcpkgToolchain = Join-Path $resolvedVcpkgRoot "scripts\buildsystems\vcpkg.cmake"

if (!(Test-Path $vcpkgToolchain)) {
    throw "vcpkg toolchain not found: $vcpkgToolchain"
}

git -C (Join-Path $repoRoot "third_party\libtorrent") submodule update --init --recursive

$buildDir = Join-Path $repoRoot "build\native\mikan_libtorrent\$Triplet"
cmake `
    -Wno-dev `
    -S (Join-Path $repoRoot "native\mikan_libtorrent") `
    -B $buildDir `
    -G "Visual Studio 17 2022" `
    -A x64 `
    -DCMAKE_TOOLCHAIN_FILE="$vcpkgToolchain" `
    -DVCPKG_TARGET_TRIPLET="$Triplet" `
    -DVCPKG_MANIFEST_DIR="$repoRoot"
if ($LASTEXITCODE -ne 0) {
    throw "CMake configure failed with exit code $LASTEXITCODE"
}

cmake --build $buildDir --config $Configuration --target mikan_libtorrent --parallel
if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed with exit code $LASTEXITCODE"
}

$dll = Join-Path $buildDir "$Configuration\mikan_libtorrent.dll"
if (Test-Path $dll) {
    Write-Host "Built: $dll"
} else {
    Write-Warning "Build completed, but DLL was not found at expected path: $dll"
}
