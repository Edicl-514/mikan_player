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

# 使用分割 ABI 构建发行版 APK
Write-Host "Building APK with split-per-abi..."
flutter build apk --release --split-per-abi

Write-Host "APK build completed!"
