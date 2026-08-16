param(
    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$Configuration = "Release",
    [string]$Triplet = "x64-windows",
    [string]$VcpkgRoot = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\vcpkg",
    [string]$Generator = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$vcpkgManifest = Join-Path $repoRoot "vcpkg.json"

function Get-UsableVcpkgRoot {
    param([string]$PreferredRoot)

    $candidates = @($PreferredRoot)
    if ($env:VCPKG_ROOT) { $candidates += $env:VCPKG_ROOT }
    if ($env:VCPKG_INSTALLATION_ROOT) { $candidates += $env:VCPKG_INSTALLATION_ROOT }
    $candidates += "C:\vcpkg"

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (!$candidate) { continue }
        $toolchain = Join-Path $candidate "scripts\buildsystems\vcpkg.cmake"
        $openSslPort = Join-Path $candidate "ports\openssl"
        $boostPort = Join-Path $candidate "ports\boost-headers"
        if ((Test-Path $toolchain) -and
            (Test-Path $openSslPort) -and
            (Test-Path $boostPort)) {
            return (Resolve-Path $candidate).Path
        }
    }

    Write-Host "No usable preinstalled vcpkg found; using build\tools\vcpkg instead."
    $localRoot = Join-Path $repoRoot "build\tools\vcpkg"
    if (!(Test-Path (Join-Path $localRoot ".git"))) {
        New-Item -ItemType Directory -Force -Path (Split-Path $localRoot -Parent) | Out-Null
        git clone --filter=blob:none https://github.com/microsoft/vcpkg.git $localRoot
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
        & (Join-Path $localRoot "bootstrap-vcpkg.bat") -disableMetrics
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to bootstrap vcpkg with exit code $LASTEXITCODE"
        }
    }

    return $localRoot
}

function Get-VisualStudioGenerator {
    param([string]$PreferredGenerator)

    if ($PreferredGenerator) { return $PreferredGenerator }
    if ($env:MIKAN_CMAKE_GENERATOR) { return $env:MIKAN_CMAKE_GENERATOR }

    # The generator name is tied to the installed Visual Studio major version, so
    # resolve it instead of hardcoding one: GitHub's windows-latest image ships
    # VS 2026 (18) only, while local machines often have VS 2022 (17).
    $generators = @{
        17 = "Visual Studio 17 2022"
        18 = "Visual Studio 18 2026"
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (!(Test-Path $vswhere)) {
        throw "vswhere.exe was not found. Install Visual Studio with the C++ toolset or pass -Generator."
    }

    $installed = @(& $vswhere -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationVersion)
    if ($installed.Count -eq 0) {
        # Fall back to any install in case the C++ component id changed.
        $installed = @(& $vswhere -products '*' -property installationVersion)
    }

    $majors = @($installed |
        Where-Object { $_ -match '^\d+' } |
        ForEach-Object { [int]($_ -split '\.')[0] } |
        Sort-Object -Unique -Descending)
    if ($majors.Count -eq 0) {
        throw "No Visual Studio installation was found. Install the C++ toolset or pass -Generator."
    }

    # Prefer VS 2022 when it is available: the vcpkg baseline pinned in vcpkg.json
    # is what this repo has been building with. Otherwise take the newest install.
    $ordered = @(17) + $majors
    foreach ($major in $ordered) {
        if (($majors -contains $major) -and $generators.ContainsKey($major)) {
            return $generators[$major]
        }
    }

    throw "No known CMake generator for Visual Studio version(s) $($majors -join ', '). Pass -Generator explicitly."
}

$resolvedVcpkgRoot = Get-UsableVcpkgRoot -PreferredRoot $VcpkgRoot
$vcpkgToolchain = Join-Path $resolvedVcpkgRoot "scripts\buildsystems\vcpkg.cmake"

if (!(Test-Path $vcpkgToolchain)) {
    throw "vcpkg toolchain not found: $vcpkgToolchain"
}

$resolvedGenerator = Get-VisualStudioGenerator -PreferredGenerator $Generator
Write-Host "Using vcpkg: $resolvedVcpkgRoot"
Write-Host "Using generator: $resolvedGenerator"

git -C (Join-Path $repoRoot "third_party\libtorrent") submodule update --init --recursive

$buildDir = Join-Path $repoRoot "build\native\mikan_libtorrent\$Triplet"

# CMake refuses to reconfigure a build tree with a different generator, which
# happens whenever the toolchain changes (e.g. a cached CI tree or a new VS).
$cmakeCache = Join-Path $buildDir "CMakeCache.txt"
if (Test-Path $cmakeCache) {
    $cachedMatch = Select-String -Path $cmakeCache -Pattern '^CMAKE_GENERATOR:INTERNAL=(.*)$' |
        Select-Object -First 1
    $cachedGenerator = if ($cachedMatch) { $cachedMatch.Matches[0].Groups[1].Value.Trim() } else { "" }
    if ($cachedGenerator -and $cachedGenerator -ne $resolvedGenerator) {
        Write-Host "Generator changed ('$cachedGenerator' -> '$resolvedGenerator'); wiping $buildDir"
        Remove-Item -Recurse -Force $buildDir
    }
}

cmake `
    -Wno-dev `
    -S (Join-Path $repoRoot "native\mikan_libtorrent") `
    -B $buildDir `
    -G "$resolvedGenerator" `
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
