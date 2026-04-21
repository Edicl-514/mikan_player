# PowerShell script to load .env variables and build Rust for Windows
param(
    [string]$BuildMode = "release",
    [string]$RustSourceDir = ".\rust",
    [switch]$SkipFlutterBuild
)

Write-Host "Building Rust code for Windows ($BuildMode output)..."

# Resolve script root and .env (same behavior as build_apk.ps1)
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$envFile = Join-Path $scriptRoot '.env'
if (Test-Path $envFile) {
    Write-Host "Loading environment variables from .env file..."
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $key, $value = $line -split '=', 2
            [Environment]::SetEnvironmentVariable($key.Trim(), $value.Trim().Trim('"'''), 'Process')
            Write-Host "Set environment variable: $($key.Trim())"
        }
    }
} else {
    Write-Host "Error: .env file not found"
    exit 1
}

# Build Rust with the requested profile.
$rustDir = if ([System.IO.Path]::IsPathRooted($RustSourceDir)) {
    $RustSourceDir
} else {
    Join-Path $scriptRoot $RustSourceDir
}
if (-not (Test-Path $rustDir)) {
    Write-Host "Rust directory not found: $rustDir"
    exit 1
}

Push-Location $rustDir
try {
    if ($BuildMode -eq "release") {
        Write-Host "Building Rust in release mode..."
        cargo build --release
    } else {
        Write-Host "Building Rust in debug mode..."
        cargo build
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Rust build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

Write-Host "Rust build completed successfully."

# Locate Rust artifacts and copy them next to the Windows runner
$artifactDir = Join-Path $rustDir "target\$BuildMode"
if (-not (Test-Path $artifactDir)) {
    Write-Error "Rust artifact directory not found: $artifactDir"
    exit 1
}

$destDir = Join-Path $scriptRoot 'windows\runner'
if (-not (Test-Path $destDir)) {
    Write-Host "Creating destination directory: $destDir"
    New-Item -ItemType Directory -Path $destDir | Out-Null
}

$patterns = @('*.dll', '*.lib', '*.a')
foreach ($pat in $patterns) {
    Get-ChildItem -Path $artifactDir -Filter $pat -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "Copying $($_.Name) -> $destDir"
        Copy-Item -Path $_.FullName -Destination $destDir -Force
    }
}

Write-Host "Copied native artifacts to $destDir"

# Build Flutter Windows release (so final installer/exe is produced).
# CMake calls this script from the rust_build target, where invoking Flutter
# again would recursively trigger rust_build.
if ($SkipFlutterBuild) {
    Write-Host "Skipping Flutter build because this script was invoked by CMake."
    exit 0
}

Write-Host "Building Flutter Windows release..."
Push-Location $scriptRoot
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flutter build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

Write-Host "Windows release build completed! Output under build\windows\runner\Release"
