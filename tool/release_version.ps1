param(
    [int]$BuildNumber = 1,
    [datetime]$UtcDate = [datetime]::UtcNow
)

$ErrorActionPreference = 'Stop'

if ($BuildNumber -lt 1) {
    throw 'BuildNumber must be a positive integer.'
}

# Flutter accepts three numeric components for build-name. UTC keeps releases
# deterministic regardless of the runner's local timezone.
$version = $UtcDate.ToString('yyyy.MM.dd', [Globalization.CultureInfo]::InvariantCulture)

[pscustomobject]@{
    Version       = $version
    BuildNumber   = $BuildNumber
    Display       = "$version+$BuildNumber"
} | ConvertTo-Json -Compress
