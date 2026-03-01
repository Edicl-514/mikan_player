# PowerShell script to load .env variables and build Rust for Windows
param(
    [string]$BuildMode = "debug",
    [string]$RustSourceDir = ".\rust"
)

Write-Host "Building Rust code for Windows..."

# Read .env file and set environment variables
$envFile = ".\.env"
if (Test-Path $envFile) {
    Write-Host "Loading environment variables from .env file..."
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $key, $value = $line -split '=', 2
            $key = $key.Trim()
            $value = $value.Trim().Trim('"').Trim("'")
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
            Write-Host "  Set: $key"
        }
    }
} else {
    Write-Host "Warning: .env file not found"
}

# Build Rust
Push-Location $RustSourceDir
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
