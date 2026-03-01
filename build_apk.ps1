# Windows PowerShell script to build APK with environment variables from .env

# 读取 .env 文件并设置环境变量（基于脚本位置）
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$envFile = Join-Path $scriptRoot '.env'
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

# ==============================================================================
# 修补 pub 缓存中的 isar_flutter_libs build.gradle（AGP 8.x 需要 namespace，SDK版本需同步）
# ==============================================================================
$isarBuildGradle = Join-Path $env:LOCALAPPDATA `
    'Pub\Cache\hosted\pub.dev\isar_flutter_libs-3.1.0+1\android\build.gradle'
if (Test-Path $isarBuildGradle) {
    $isarContent = Get-Content $isarBuildGradle -Raw
    $needsPatch = $false
    
    # 检查并补充 namespace
    if ($isarContent -notmatch "namespace\s+'dev\.isar\.isar_flutter_libs'") {
        Write-Host "Patching isar_flutter_libs: adding namespace..."
        $isarContent = $isarContent -replace `
            "(apply plugin: 'com\.android\.library'\s+android \{)", `
            "`$1`n    namespace 'dev.isar.isar_flutter_libs'"
        $needsPatch = $true
    }
    
    # 检查并升级 compileSdkVersion 到 36（与主项目保持一致）
    if ($isarContent -match "compileSdkVersion\s+30") {
        Write-Host "Patching isar_flutter_libs: upgrading compileSdkVersion to 36..."
        $isarContent = $isarContent -replace 'compileSdkVersion\s+30', 'compileSdkVersion 36'
        $needsPatch = $true
    }
    
    # 检查并升级 minSdkVersion 到 21
    if ($isarContent -match "minSdkVersion\s+16") {
        Write-Host "Patching isar_flutter_libs: upgrading minSdkVersion to 21..."
        $isarContent = $isarContent -replace 'minSdkVersion\s+16', 'minSdkVersion 21'
        $needsPatch = $true
    }
    
    if ($needsPatch) {
        Set-Content -Path $isarBuildGradle -Value $isarContent -NoNewline
        Write-Host "Isar patches applied."
    } else {
        Write-Host "Isar build.gradle already patched, skipping."
    }
} else {
    Write-Host "Warning: isar_flutter_libs build.gradle not found at: $isarBuildGradle"
}

# Build Rust native libraries before building APK (use paths relative to script)
Write-Host "Building Rust native libraries for multiple ABIs..."
$rustDir = Join-Path $scriptRoot 'rust'
if (-not (Test-Path $rustDir)) {
    Write-Host "Rust directory not found: $rustDir"
    exit 1
}
Push-Location $rustDir
try {
    $env:OPENSSL_DIR = Join-Path $rustDir 'openssl\usr\local'
    $env:OPENSSL_STATIC = '1'
    Write-Host "Set OPENSSL_DIR=$env:OPENSSL_DIR and OPENSSL_STATIC=$env:OPENSSL_STATIC"

    $jniLibsDir = Join-Path $scriptRoot 'android\app\src\main\jniLibs'
    if (Test-Path $jniLibsDir) {
        Write-Host "Removing existing jniLibs at $jniLibsDir"
        Remove-Item -Recurse -Force $jniLibsDir
    }
    New-Item -ItemType Directory -Path $jniLibsDir | Out-Null

    # Only build for arm64-v8a to avoid linker issues with other ABIs
    $abis = @('arm64-v8a')
    foreach ($abi in $abis) {
        $args = @('ndk','-t',$abi,'-o',$jniLibsDir,'build','--release')
        Write-Host "Running: cargo $($args -join ' ')"
        $p = Start-Process -FilePath 'cargo' -ArgumentList $args -NoNewWindow -Wait -PassThru
        if ($p.ExitCode -ne 0) {
            Write-Host "cargo ndk failed for $abi with exit code $($p.ExitCode)"
            exit $p.ExitCode
        }
    }
} catch {
    Write-Host "Exception building Rust: $_"
    exit 1
} finally {
    Pop-Location
}

Write-Host "Rust build completed for all ABIs."

# 构建单一 release APK（包含所有本地库与资源，避免语言资源被分割）
Write-Host "Building single release APK (no ABI split)..."
flutter build apk --release --split-per-abi

Write-Host "APK build completed!"
