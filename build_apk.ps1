# Windows PowerShell script to build APK with environment variables from .env

# 读取 .env 文件并设置环境变量
$envFile = ".\.env"
if (Test-Path $envFile) {
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

# Build Rust native libraries before building APK
Write-Host "Building Rust native libraries..."
$rustDir = "d:\code\mikan_player\rust"
if (-not (Test-Path $rustDir)) {
    Write-Host "Rust directory not found: $rustDir"
    exit 1
}
Push-Location $rustDir
try {
    $env:OPENSSL_DIR = 'D:\code\mikan_player\rust\openssl\usr\local'
    $env:OPENSSL_STATIC = '1'
    Write-Host "Set OPENSSL_DIR=$env:OPENSSL_DIR and OPENSSL_STATIC=$env:OPENSSL_STATIC"
    $args = @('ndk','-t','arm64-v8a','-o','..\android\app\src\main\jniLibs','build','--release')
    Write-Host "Running: cargo $($args -join ' ')"
    $p = Start-Process -FilePath 'cargo' -ArgumentList $args -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        Write-Host "cargo ndk failed with exit code $($p.ExitCode)"
        exit $p.ExitCode
    }
} catch {
    Write-Host "Exception building Rust: $_"
    exit 1
} finally {
    Pop-Location
}

Write-Host "Rust build completed."

# 使用分割 ABI 构建发行版 APK
Write-Host "Building APK with split-per-abi..."
flutter build apk --release --split-per-abi

Write-Host "APK build completed!"
