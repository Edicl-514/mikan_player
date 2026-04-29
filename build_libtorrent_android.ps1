param(
    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$Configuration = "MinSizeRel",
    [ValidateSet("arm64-v8a")]
    [string]$Abi = "arm64-v8a",
    [string]$Triplet = "arm64-android",
    [string]$AndroidPlatform = "android-24",
    [string]$VcpkgRoot = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\vcpkg",
    [string]$OpenSslRoot = "",
    [string]$OutputJniLibsDir = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$ndkVersion = "29.0.14206865"
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
                    throw "Failed to checkout vcpkg baseline $baseline with exit code $LASTEXITCODE"
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

function Get-AndroidNdkRoot {
    $candidates = @()
    if ($env:ANDROID_NDK_HOME) { $candidates += $env:ANDROID_NDK_HOME }
    if ($env:ANDROID_NDK_ROOT) { $candidates += $env:ANDROID_NDK_ROOT }
    if ($env:ANDROID_HOME) { $candidates += (Join-Path $env:ANDROID_HOME "ndk\$ndkVersion") }
    if ($env:ANDROID_SDK_ROOT) { $candidates += (Join-Path $env:ANDROID_SDK_ROOT "ndk\$ndkVersion") }
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA "Android\Sdk\ndk\$ndkVersion") }

    foreach ($candidate in $candidates) {
        if (!$candidate) {
            continue
        }
        $toolchain = Join-Path $candidate "build\cmake\android.toolchain.cmake"
        if (Test-Path $toolchain) {
            return (Resolve-Path $candidate).Path
        }
    }

    throw "Android NDK $ndkVersion was not found. Install it with Android Studio or set ANDROID_NDK_HOME."
}

function Get-NinjaPath {
    $command = Get-Command ninja -ErrorAction SilentlyContinue
    if ($command -and (Test-Path $command.Source)) {
        return $command.Source
    }

    $sdkRoots = @()
    if ($env:ANDROID_HOME) { $sdkRoots += $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT) { $sdkRoots += $env:ANDROID_SDK_ROOT }
    if ($env:LOCALAPPDATA) { $sdkRoots += (Join-Path $env:LOCALAPPDATA "Android\Sdk") }
    $sdkRoots += (Split-Path $ndkRoot -Parent | Split-Path -Parent)

    foreach ($sdkRoot in $sdkRoots | Select-Object -Unique) {
        if (!$sdkRoot -or !(Test-Path $sdkRoot)) {
            continue
        }
        $ninja = Get-ChildItem -Path (Join-Path $sdkRoot "cmake") -Recurse -Filter ninja.exe -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($ninja) {
            return $ninja.FullName
        }
    }

    return ""
}

function Get-AndroidLlvmStripPath {
    param([string]$NdkRoot)

    $strip = Join-Path $NdkRoot "toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe"
    if (Test-Path $strip) {
        return $strip
    }

    return ""
}

if ($Abi -ne "arm64-v8a") {
    throw "Only arm64-v8a is wired up right now."
}

$resolvedVcpkgRoot = Get-UsableVcpkgRoot -PreferredRoot $VcpkgRoot
$vcpkgToolchain = Join-Path $resolvedVcpkgRoot "scripts\buildsystems\vcpkg.cmake"
if (!(Test-Path $vcpkgToolchain)) {
    throw "vcpkg toolchain not found: $vcpkgToolchain"
}

if (!$OpenSslRoot) {
    $OpenSslRoot = Join-Path $repoRoot "rust\openssl\usr\local"
}
if (Test-Path $OpenSslRoot) {
    $OpenSslRoot = (Resolve-Path $OpenSslRoot).Path
    $opensslSsl = Join-Path $OpenSslRoot "lib\libssl.a"
    $opensslCrypto = Join-Path $OpenSslRoot "lib\libcrypto.a"
    if (!(Test-Path $opensslSsl) -or !(Test-Path $opensslCrypto)) {
        throw "OpenSSL static libraries were not found under: $OpenSslRoot"
    }
} else {
    throw "OpenSSL root was not found: $OpenSslRoot"
}

$ndkRoot = Get-AndroidNdkRoot
$androidToolchain = Join-Path $ndkRoot "build\cmake\android.toolchain.cmake"
$env:ANDROID_NDK_HOME = $ndkRoot
$env:ANDROID_NDK_ROOT = $ndkRoot
$ninjaPath = Get-NinjaPath
$stripPath = Get-AndroidLlvmStripPath -NdkRoot $ndkRoot

Write-Host "Using Android NDK: $ndkRoot"
Write-Host "Using vcpkg: $resolvedVcpkgRoot"
Write-Host "Using OpenSSL: $OpenSslRoot"
if ($ninjaPath) {
    Write-Host "Using Ninja: $ninjaPath"
} else {
    throw "Ninja was not found. Install Android SDK CMake or put ninja.exe on PATH."
}

git -C (Join-Path $repoRoot "third_party\libtorrent") submodule update --init --recursive
if ($LASTEXITCODE -ne 0) {
    throw "Failed to update libtorrent submodules with exit code $LASTEXITCODE"
}

$buildDir = Join-Path $repoRoot "build\native\mikan_libtorrent\android\$Abi"
cmake `
    -Wno-dev `
    -S (Join-Path $repoRoot "native\mikan_libtorrent") `
    -B $buildDir `
    -G "Ninja" `
    -DCMAKE_BUILD_TYPE="$Configuration" `
    -DCMAKE_TOOLCHAIN_FILE="$vcpkgToolchain" `
    -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="$androidToolchain" `
    -DVCPKG_TARGET_TRIPLET="$Triplet" `
    -DVCPKG_MANIFEST_DIR="$repoRoot" `
    -DANDROID_ABI="$Abi" `
    -DANDROID_PLATFORM="$AndroidPlatform" `
    -DMIKAN_OPENSSL_ROOT="$OpenSslRoot" `
    -DOPENSSL_USE_STATIC_LIBS=ON `
    -DOPENSSL_ROOT_DIR="$OpenSslRoot" `
    -DOPENSSL_INCLUDE_DIR="$OpenSslRoot/include" `
    -DOPENSSL_SSL_LIBRARY="$OpenSslRoot/lib/libssl.a" `
    -DOPENSSL_CRYPTO_LIBRARY="$OpenSslRoot/lib/libcrypto.a" `
    -DCMAKE_MAKE_PROGRAM="$ninjaPath"
if ($LASTEXITCODE -ne 0) {
    throw "CMake configure failed with exit code $LASTEXITCODE"
}

cmake --build $buildDir --config $Configuration --target mikan_libtorrent --parallel
if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed with exit code $LASTEXITCODE"
}

$so = Join-Path $buildDir "libmikan_libtorrent.so"
if (!(Test-Path $so)) {
    $so = Join-Path $buildDir "$Configuration\libmikan_libtorrent.so"
}
if (!(Test-Path $so)) {
    throw "Build completed, but libmikan_libtorrent.so was not found under: $buildDir"
}

Write-Host "Built: $so"

if ($OutputJniLibsDir) {
    $abiOutputDir = Join-Path $OutputJniLibsDir $Abi
    New-Item -ItemType Directory -Force -Path $abiOutputDir | Out-Null
    $outputSo = Join-Path $abiOutputDir "libmikan_libtorrent.so"
    Copy-Item -Path $so -Destination $outputSo -Force
    if ($Configuration -ne "Debug" -and $stripPath) {
        & $stripPath --strip-all $outputSo
        if ($LASTEXITCODE -ne 0) {
            throw "llvm-strip failed with exit code $LASTEXITCODE"
        }
        Write-Host "Stripped: $outputSo"
    }
    Write-Host "Copied libmikan_libtorrent.so -> $abiOutputDir"
}
