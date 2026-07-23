param(
    [string]$PackageName,
    [ValidateRange(1, 86400)]
    [int]$DurationSeconds = 30,
    [ValidateRange(100, 60000)]
    [int]$IntervalMilliseconds = 1000,
    [ValidateRange(1, 3600)]
    [int]$LaunchTimeoutSeconds = 120,
    [string]$OutputPath,
    [string]$ProcessOutputPath,
    [string]$Serial
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PackageName)) {
    $PackageName = Read-Host "Android package name"
}
if ([string]::IsNullOrWhiteSpace($PackageName)) {
    throw "PackageName cannot be empty."
}

$adbTarget = @()
if (-not [string]::IsNullOrWhiteSpace($Serial)) {
    $adbTarget = @("-s", $Serial)
}

& adb @adbTarget get-state *> $null
if ($LASTEXITCODE -ne 0) {
    throw "No usable adb device was found. Connect a device or pass -Serial."
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $safePackageName = $PackageName -replace '[^A-Za-z0-9._-]', '_'
    $fileName = "memory-{0}-{1}.csv" -f $safePackageName, (Get-Date -Format "yyyyMMdd-HHmmss")
    $OutputPath = Join-Path (Get-Location) $fileName
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path (Get-Location) $OutputPath
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    throw "Output directory does not exist: $outputDirectory"
}
if (Test-Path -LiteralPath $OutputPath) {
    throw "Output file already exists: $OutputPath"
}

if ([string]::IsNullOrWhiteSpace($ProcessOutputPath)) {
    $outputExtension = [System.IO.Path]::GetExtension($OutputPath)
    $outputStem = if ([string]::IsNullOrEmpty($outputExtension)) {
        $OutputPath
    } else {
        $OutputPath.Substring(0, $OutputPath.Length - $outputExtension.Length)
    }
    $ProcessOutputPath = "$outputStem.processes.csv"
} elseif (-not [System.IO.Path]::IsPathRooted($ProcessOutputPath)) {
    $ProcessOutputPath = Join-Path (Get-Location) $ProcessOutputPath
}
$ProcessOutputPath = [System.IO.Path]::GetFullPath($ProcessOutputPath)

$processOutputDirectory = Split-Path -Parent $ProcessOutputPath
if (-not (Test-Path -LiteralPath $processOutputDirectory -PathType Container)) {
    throw "Process output directory does not exist: $processOutputDirectory"
}
if (Test-Path -LiteralPath $ProcessOutputPath) {
    throw "Process output file already exists: $ProcessOutputPath"
}
if ($ProcessOutputPath -eq $OutputPath) {
    throw "ProcessOutputPath must be different from OutputPath."
}

function Get-AppPid {
    $pidOutput = & adb @adbTarget shell pidof $PackageName 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $pidOutput) {
        return $null
    }

    # pidof can return more than one PID. Prefer the first process reported.
    return (($pidOutput -join " ").Trim() -split '\s+')[0]
}

function Get-AppProcessDescriptors {
    # Fallback for Android versions that do not support `dumpsys meminfo
    # --package`. Include both conventional package-named processes and every
    # process sharing the main process UID. The latter covers services whose
    # android:process name is not package-prefixed.
    $psOutput = & adb @adbTarget shell ps -A -o PID,UID,NAME 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $psOutput) {
        return @()
    }

    $descriptors = @()
    foreach ($line in $psOutput) {
        $match = [regex]::Match($line, '^\s*(\d+)\s+(\S+)\s+(.+?)\s*$')
        if (-not $match.Success) {
            continue
        }
        $descriptors += [pscustomobject]@{
            Pid  = $match.Groups[1].Value
            Uid  = $match.Groups[2].Value
            Name = $match.Groups[3].Value
        }
    }

    $main = $descriptors | Where-Object { $_.Name -eq $PackageName } | Select-Object -First 1
    $appUid = if ($null -ne $main) { $main.Uid } else { $null }
    return @(
        $descriptors | Where-Object {
            $_.Name -eq $PackageName -or
            $_.Name.StartsWith("${PackageName}:", [System.StringComparison]::Ordinal) -or
            ($null -ne $appUid -and $_.Uid -eq $appUid)
        }
    )
}

function Get-SummaryPair {
    param(
        [string]$Text,
        [string]$Label
    )

    $pattern = '(?m)^\s*{0}:\s+(\d+)(?:\s+(\d+))?\s*$' -f [regex]::Escape($Label)
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return [pscustomobject]@{
        PssKb = [long]$match.Groups[1].Value
        RssKb = if ($match.Groups[2].Success) { [long]$match.Groups[2].Value } else { $null }
    }
}

function Get-HeapRow {
    param(
        [string]$Text,
        [string]$Label
    )

    $pattern = '(?m)^\s*{0}\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$' -f [regex]::Escape($Label)
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return [pscustomobject]@{
        PssKb       = [long]$match.Groups[1].Value
        RssKb       = [long]$match.Groups[5].Value
        HeapSizeKb  = [long]$match.Groups[6].Value
        HeapAllocKb = [long]$match.Groups[7].Value
        HeapFreeKb  = [long]$match.Groups[8].Value
    }
}

function Get-StatusValue {
    param(
        [string]$Text,
        [string]$Name
    )

    $match = [regex]::Match($Text, "(?m)^$([regex]::Escape($Name)):\s+(\d+)\s+kB\s*$")
    if ($match.Success) {
        return [long]$match.Groups[1].Value
    }
    return $null
}

function Get-ObjectValue {
    param(
        [object]$Object,
        [string]$Property
    )

    if ($null -eq $Object) {
        return $null
    }
    return $Object.$Property
}

function Convert-MemInfoToMetrics {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $totalMatch = [regex]::Match(
        $Text,
        '(?m)^\s*TOTAL PSS:\s+(\d+).*?TOTAL RSS:\s+(\d+).*?TOTAL SWAP PSS:\s+(\d+)\s*$'
    )
    if (-not $totalMatch.Success) {
        return $null
    }

    $javaHeap = Get-SummaryPair -Text $Text -Label "Java Heap"
    $nativeHeap = Get-SummaryPair -Text $Text -Label "Native Heap"
    $graphics = Get-SummaryPair -Text $Text -Label "Graphics"
    $code = Get-SummaryPair -Text $Text -Label "Code"
    $stack = Get-SummaryPair -Text $Text -Label "Stack"
    $privateOther = Get-SummaryPair -Text $Text -Label "Private Other"
    $system = Get-SummaryPair -Text $Text -Label "System"
    $nativeHeapRow = Get-HeapRow -Text $Text -Label "Native Heap"
    $dalvikHeapRow = Get-HeapRow -Text $Text -Label "Dalvik Heap"

    return [pscustomobject]@{
        TotalPssKb        = [long]$totalMatch.Groups[1].Value
        TotalRssKb        = [long]$totalMatch.Groups[2].Value
        TotalSwapPssKb    = [long]$totalMatch.Groups[3].Value
        JavaHeapPssKb     = Get-ObjectValue $javaHeap "PssKb"
        JavaHeapRssKb     = Get-ObjectValue $javaHeap "RssKb"
        NativeHeapPssKb   = Get-ObjectValue $nativeHeap "PssKb"
        NativeHeapRssKb   = Get-ObjectValue $nativeHeap "RssKb"
        NativeHeapSizeKb  = Get-ObjectValue $nativeHeapRow "HeapSizeKb"
        NativeHeapAllocKb = Get-ObjectValue $nativeHeapRow "HeapAllocKb"
        NativeHeapFreeKb  = Get-ObjectValue $nativeHeapRow "HeapFreeKb"
        DalvikHeapPssKb   = Get-ObjectValue $dalvikHeapRow "PssKb"
        DalvikHeapRssKb   = Get-ObjectValue $dalvikHeapRow "RssKb"
        DalvikHeapSizeKb  = Get-ObjectValue $dalvikHeapRow "HeapSizeKb"
        DalvikHeapAllocKb = Get-ObjectValue $dalvikHeapRow "HeapAllocKb"
        DalvikHeapFreeKb  = Get-ObjectValue $dalvikHeapRow "HeapFreeKb"
        GraphicsPssKb     = Get-ObjectValue $graphics "PssKb"
        GraphicsRssKb     = Get-ObjectValue $graphics "RssKb"
        CodePssKb         = Get-ObjectValue $code "PssKb"
        StackPssKb        = Get-ObjectValue $stack "PssKb"
        PrivateOtherPssKb = Get-ObjectValue $privateOther "PssKb"
        SystemPssKb       = Get-ObjectValue $system "PssKb"
    }
}

function Get-ProcessKind {
    param([string]$Name)

    if ($Name -eq $PackageName) {
        return "Main"
    }
    if ($Name -match '(?i)(sandboxed_process|privileged_process|webview)') {
        return "WebViewRenderer"
    }
    if ($Name.StartsWith("${PackageName}:", [System.StringComparison]::Ordinal)) {
        return "AppSubprocess"
    }
    return "PackageAssociated"
}

function Get-ProcessStatus {
    param([string]$ProcessId)

    $statusOutput = & adb @adbTarget shell cat "/proc/$ProcessId/status" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $statusOutput) {
        return $null
    }
    return $statusOutput -join [Environment]::NewLine
}

function New-ProcessMemoryRecord {
    param(
        [string]$ProcessId,
        [string]$ProcessName,
        [string]$Uid,
        [string]$MemInfoText
    )

    $metrics = Convert-MemInfoToMetrics -Text $MemInfoText
    if ($null -eq $metrics) {
        return $null
    }

    $status = Get-ProcessStatus -ProcessId $ProcessId
    return [pscustomobject]@{
        Pid                   = $ProcessId
        ProcessName           = $ProcessName
        ProcessKind           = Get-ProcessKind -Name $ProcessName
        Uid                   = $Uid
        TotalPssKb            = $metrics.TotalPssKb
        TotalRssKb            = $metrics.TotalRssKb
        TotalSwapPssKb        = $metrics.TotalSwapPssKb
        JavaHeapPssKb         = $metrics.JavaHeapPssKb
        JavaHeapRssKb         = $metrics.JavaHeapRssKb
        NativeHeapPssKb       = $metrics.NativeHeapPssKb
        NativeHeapRssKb       = $metrics.NativeHeapRssKb
        NativeHeapSizeKb      = $metrics.NativeHeapSizeKb
        NativeHeapAllocKb     = $metrics.NativeHeapAllocKb
        NativeHeapFreeKb      = $metrics.NativeHeapFreeKb
        DalvikHeapPssKb       = $metrics.DalvikHeapPssKb
        DalvikHeapRssKb       = $metrics.DalvikHeapRssKb
        DalvikHeapSizeKb      = $metrics.DalvikHeapSizeKb
        DalvikHeapAllocKb     = $metrics.DalvikHeapAllocKb
        DalvikHeapFreeKb      = $metrics.DalvikHeapFreeKb
        GraphicsPssKb         = $metrics.GraphicsPssKb
        GraphicsRssKb         = $metrics.GraphicsRssKb
        CodePssKb             = $metrics.CodePssKb
        StackPssKb            = $metrics.StackPssKb
        PrivateOtherPssKb     = $metrics.PrivateOtherPssKb
        SystemPssKb           = $metrics.SystemPssKb
        VmRssKb               = if ($status) { Get-StatusValue $status "VmRSS" } else { $null }
        VmHwmKb               = if ($status) { Get-StatusValue $status "VmHWM" } else { $null }
        RssAnonKb             = if ($status) { Get-StatusValue $status "RssAnon" } else { $null }
        RssFileKb             = if ($status) { Get-StatusValue $status "RssFile" } else { $null }
        VmSwapKb              = if ($status) { Get-StatusValue $status "VmSwap" } else { $null }
    }
}

function Get-PackageMemorySnapshot {
    # `--package` asks Android to include every process that has loaded the
    # package. This is more complete than pidof and can include isolated WebView
    # renderer processes whose Linux UID and process name differ from the app.
    $packageOutput = & adb @adbTarget shell dumpsys meminfo --package $PackageName 2>&1
    if ($LASTEXITCODE -eq 0 -and $packageOutput) {
        $packageText = $packageOutput -join [Environment]::NewLine
        $headings = [regex]::Matches(
            $packageText,
            '(?m)^\s*\*\* MEMINFO in pid (\d+) \[([^\]]+)\] \*\*\s*$'
        )
        if ($headings.Count -gt 0) {
            $records = @()
            for ($index = 0; $index -lt $headings.Count; $index++) {
                $heading = $headings[$index]
                $blockEnd = if ($index + 1 -lt $headings.Count) {
                    $headings[$index + 1].Index
                } else {
                    $packageText.Length
                }
                $block = $packageText.Substring($heading.Index, $blockEnd - $heading.Index)
                $pidValue = $heading.Groups[1].Value
                $nameValue = $heading.Groups[2].Value
                $status = Get-ProcessStatus -ProcessId $pidValue
                $uidValue = if ($status) {
                    $uidMatch = [regex]::Match($status, '(?m)^Uid:\s+(\d+)')
                    if ($uidMatch.Success) { $uidMatch.Groups[1].Value } else { $null }
                } else {
                    $null
                }
                $record = New-ProcessMemoryRecord -ProcessId $pidValue -ProcessName $nameValue -Uid $uidValue -MemInfoText $block
                if ($null -ne $record) {
                    $records += $record
                }
            }
            if ($records.Count -gt 0) {
                # Some Android builds repeat a process heading when package
                # details are requested with extra meminfo sections. A PID must
                # contribute exactly once to the package total.
                $records = @(
                    $records | Group-Object -Property Pid | ForEach-Object { $_.Group[0] }
                )
                return [pscustomobject]@{
                    Processes = @($records)
                    Discovery = "dumpsys-meminfo-package"
                    Error     = $null
                }
            }
        }
    }

    # Older Android releases may not implement --package. Fall back to process
    # table discovery and query each PID independently.
    $fallbackRecords = @()
    $descriptors = @(Get-AppProcessDescriptors)
    foreach ($descriptor in $descriptors) {
        $meminfoOutput = & adb @adbTarget shell dumpsys meminfo $descriptor.Pid 2>&1
        if ($LASTEXITCODE -ne 0 -or -not $meminfoOutput) {
            continue
        }
        $record = New-ProcessMemoryRecord `
            -ProcessId $descriptor.Pid `
            -ProcessName $descriptor.Name `
            -Uid $descriptor.Uid `
            -MemInfoText ($meminfoOutput -join [Environment]::NewLine)
        if ($null -ne $record) {
            $fallbackRecords += $record
        }
    }

    $fallbackError = if ($fallbackRecords.Count -eq 0) {
        "No package process memory could be read."
    } else {
        $null
    }
    return [pscustomobject]@{
        Processes = @($fallbackRecords)
        Discovery = "ps-name-and-uid-fallback"
        Error     = $fallbackError
    }
}

function Get-PropertySum {
    param(
        [object[]]$Items,
        [string]$Property
    )

    $values = @(
        foreach ($item in $Items) {
            $value = $item.$Property
            if ($null -ne $value -and "$value" -ne "") {
                [long]$value
            }
        }
    )
    if ($values.Count -eq 0) {
        return $null
    }
    return [long](($values | Measure-Object -Sum).Sum)
}

function Get-BatteryValue {
    param(
        [string]$Text,
        [string]$Name
    )

    $match = [regex]::Match($Text, "(?m)^\s*$([regex]::Escape($Name)):\s*(-?\d+)\s*$")
    if ($match.Success) {
        return [long]$match.Groups[1].Value
    }
    return $null
}

function Get-BatteryPowerSupplyValue {
    param([string]$Name)

    $path = "/sys/class/power_supply/battery/$Name"
    if ($script:BatterySysfsNeedsRoot) {
        $valueOutput = & adb @adbTarget shell su -c "cat $path" 2>$null
    } else {
        $valueOutput = & adb @adbTarget shell cat $path 2>$null
        if ($LASTEXITCODE -ne 0 -and $script:BatteryRootAvailable -ne $false) {
            $rootOutput = & adb @adbTarget shell su -c id 2>$null
            $script:BatteryRootAvailable = $LASTEXITCODE -eq 0 -and (($rootOutput -join " ") -match 'uid=0')
            if ($script:BatteryRootAvailable) {
                $script:BatterySysfsNeedsRoot = $true
                $valueOutput = & adb @adbTarget shell su -c "cat $path" 2>$null
            }
        }
    }

    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $valueText = ($valueOutput -join " ").Trim()
    if ($valueText -match '^-?\d+$') {
        return [long]$valueText
    }
    return $null
}

function Get-BatteryMetrics {
    $batteryOutput = & adb @adbTarget shell dumpsys battery 2>$null
    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject]@{}
    }

    $batteryText = $batteryOutput -join [Environment]::NewLine
    # Most Android kernels expose these values in micro-units. Querying the files
    # individually keeps the script usable on devices that expose only a subset.
    $currentNowUa = Get-BatteryPowerSupplyValue -Name "current_now"
    $voltageNowUv = Get-BatteryPowerSupplyValue -Name "voltage_now"
    $powerNowUw = Get-BatteryPowerSupplyValue -Name "power_now"

    $status = Get-BatteryValue -Text $batteryText -Name "status"
    $voltageMv = Get-BatteryValue -Text $batteryText -Name "voltage"
    if ($null -eq $voltageNowUv -and $null -ne $voltageMv) {
        $voltageNowUv = $voltageMv * 1000
    }

    $dischargePowerMw = $null
    if ($status -eq 3) { # Android BatteryManager.BATTERY_STATUS_DISCHARGING
        if ($null -ne $currentNowUa -and $null -ne $voltageNowUv) {
            $dischargePowerMw = [math]::Abs($currentNowUa * $voltageNowUv) / 1000000000.0
        } elseif ($null -ne $powerNowUw) {
            $dischargePowerMw = [math]::Abs($powerNowUw) / 1000.0
        }
    }

    return [pscustomobject]@{
        Status                   = $status
        LevelPercent             = Get-BatteryValue -Text $batteryText -Name "level"
        TemperatureTenthsC       = Get-BatteryValue -Text $batteryText -Name "temperature"
        VoltageMv                = $voltageMv
        CurrentUa                = $currentNowUa
        VoltageUv                = $voltageNowUv
        PowerUw                  = $powerNowUw
        DischargePowerMw         = $dischargePowerMw
    }
}

Write-Host "Waiting up to $LaunchTimeoutSeconds seconds for $PackageName ..."
$launchTimer = [System.Diagnostics.Stopwatch]::StartNew()
$appPid = Get-AppPid
while (-not $appPid -and $launchTimer.Elapsed.TotalSeconds -lt $LaunchTimeoutSeconds) {
    Start-Sleep -Milliseconds 500
    $appPid = Get-AppPid
}
if (-not $appPid) {
    throw "Timed out waiting for $PackageName. Start the app and try again."
}

Write-Host "Detected PID $appPid. Recording for $DurationSeconds seconds."
Write-Host "Summary CSV: $OutputPath"
Write-Host "Process CSV: $ProcessOutputPath"

$timer = [System.Diagnostics.Stopwatch]::StartNew()
$durationMilliseconds = $DurationSeconds * 1000
$nextSampleMilliseconds = 0
$sampleIndex = 0
$csvStarted = $false
$processCsvStarted = $false

while ($true) {
    $elapsedMilliseconds = [long]$timer.Elapsed.TotalMilliseconds
    if ($elapsedMilliseconds -lt $nextSampleMilliseconds) {
        Start-Sleep -Milliseconds ($nextSampleMilliseconds - $elapsedMilliseconds)
    }

    $sampleElapsedMilliseconds = [long]$timer.Elapsed.TotalMilliseconds
    $sampleTime = Get-Date
    $collectionTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $snapshot = Get-PackageMemorySnapshot
    $processes = @($snapshot.Processes | Sort-Object { [long]$_.Pid })
    $battery = Get-BatteryMetrics
    $collectionTimer.Stop()

    $mainProcess = $processes | Where-Object { $_.ProcessKind -eq "Main" } | Select-Object -First 1
    $currentPid = if ($null -ne $mainProcess) { $mainProcess.Pid } else { $null }
    $processState = if ($processes.Count -gt 0) { "Running" } else { "NotRunning" }
    $sampleError = $snapshot.Error
    if ($snapshot.Discovery -ne "dumpsys-meminfo-package" -and $sampleIndex -eq 0) {
        Write-Warning "Android --package meminfo is unavailable; using ps name/UID fallback. Isolated WebView processes may be missing."
    }

    $totalPssKb = Get-PropertySum -Items $processes -Property "TotalPssKb"
    $totalRssKb = Get-PropertySum -Items $processes -Property "TotalRssKb"
    $totalSwapPssKb = Get-PropertySum -Items $processes -Property "TotalSwapPssKb"

    $row = [pscustomobject][ordered]@{
        Timestamp             = $sampleTime.ToString("o")
        ElapsedMs             = $sampleElapsedMilliseconds
        CollectionMs          = [long]$collectionTimer.Elapsed.TotalMilliseconds
        Sample                = $sampleIndex
        PackageName           = $PackageName
        Pid                   = $currentPid
        MainPid               = $currentPid
        ProcessCount          = $processes.Count
        Pids                  = ($processes.Pid -join ";")
        ProcessNames          = ($processes.ProcessName -join ";")
        ProcessDiscovery      = $snapshot.Discovery
        ProcessState          = $processState
        TotalPssKb            = $totalPssKb
        TotalRssKb            = $totalRssKb
        TotalSwapPssKb        = $totalSwapPssKb
        JavaHeapPssKb         = Get-PropertySum -Items $processes -Property "JavaHeapPssKb"
        JavaHeapRssKb         = Get-PropertySum -Items $processes -Property "JavaHeapRssKb"
        NativeHeapPssKb       = Get-PropertySum -Items $processes -Property "NativeHeapPssKb"
        NativeHeapRssKb       = Get-PropertySum -Items $processes -Property "NativeHeapRssKb"
        NativeHeapSizeKb      = Get-PropertySum -Items $processes -Property "NativeHeapSizeKb"
        NativeHeapAllocKb     = Get-PropertySum -Items $processes -Property "NativeHeapAllocKb"
        NativeHeapFreeKb      = Get-PropertySum -Items $processes -Property "NativeHeapFreeKb"
        DalvikHeapPssKb       = Get-PropertySum -Items $processes -Property "DalvikHeapPssKb"
        DalvikHeapRssKb       = Get-PropertySum -Items $processes -Property "DalvikHeapRssKb"
        DalvikHeapSizeKb      = Get-PropertySum -Items $processes -Property "DalvikHeapSizeKb"
        DalvikHeapAllocKb     = Get-PropertySum -Items $processes -Property "DalvikHeapAllocKb"
        DalvikHeapFreeKb      = Get-PropertySum -Items $processes -Property "DalvikHeapFreeKb"
        GraphicsPssKb         = Get-PropertySum -Items $processes -Property "GraphicsPssKb"
        GraphicsRssKb         = Get-PropertySum -Items $processes -Property "GraphicsRssKb"
        CodePssKb             = Get-PropertySum -Items $processes -Property "CodePssKb"
        StackPssKb            = Get-PropertySum -Items $processes -Property "StackPssKb"
        PrivateOtherPssKb     = Get-PropertySum -Items $processes -Property "PrivateOtherPssKb"
        SystemPssKb           = Get-PropertySum -Items $processes -Property "SystemPssKb"
        VmRssKb               = Get-PropertySum -Items $processes -Property "VmRssKb"
        VmHwmKb               = Get-PropertySum -Items $processes -Property "VmHwmKb"
        RssAnonKb             = Get-PropertySum -Items $processes -Property "RssAnonKb"
        RssFileKb             = Get-PropertySum -Items $processes -Property "RssFileKb"
        VmSwapKb              = Get-PropertySum -Items $processes -Property "VmSwapKb"
        BatteryStatus          = Get-ObjectValue $battery "Status"
        BatteryLevelPercent    = Get-ObjectValue $battery "LevelPercent"
        BatteryTemperatureC    = if ($null -ne (Get-ObjectValue $battery "TemperatureTenthsC")) { (Get-ObjectValue $battery "TemperatureTenthsC") / 10.0 } else { $null }
        BatteryVoltageMv       = Get-ObjectValue $battery "VoltageMv"
        BatteryCurrentUa       = Get-ObjectValue $battery "CurrentUa"
        BatteryVoltageUv       = Get-ObjectValue $battery "VoltageUv"
        BatteryPowerUw         = Get-ObjectValue $battery "PowerUw"
        BatteryDischargePowerMw = Get-ObjectValue $battery "DischargePowerMw"
        Error                 = $sampleError
    }

    if ($csvStarted) {
        $row | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8 -Append
    } else {
        $row | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
        $csvStarted = $true
    }

    $processRows = @(
        foreach ($process in $processes) {
            [pscustomobject][ordered]@{
                Timestamp             = $sampleTime.ToString("o")
                ElapsedMs             = $sampleElapsedMilliseconds
                CollectionMs          = [long]$collectionTimer.ElapsedMilliseconds
                Sample                = $sampleIndex
                PackageName           = $PackageName
                ProcessDiscovery      = $snapshot.Discovery
                Pid                   = $process.Pid
                ProcessName           = $process.ProcessName
                ProcessKind           = $process.ProcessKind
                Uid                   = $process.Uid
                TotalPssKb            = $process.TotalPssKb
                TotalRssKb            = $process.TotalRssKb
                TotalSwapPssKb        = $process.TotalSwapPssKb
                JavaHeapPssKb         = $process.JavaHeapPssKb
                JavaHeapRssKb         = $process.JavaHeapRssKb
                NativeHeapPssKb       = $process.NativeHeapPssKb
                NativeHeapRssKb       = $process.NativeHeapRssKb
                NativeHeapSizeKb      = $process.NativeHeapSizeKb
                NativeHeapAllocKb     = $process.NativeHeapAllocKb
                NativeHeapFreeKb      = $process.NativeHeapFreeKb
                DalvikHeapPssKb       = $process.DalvikHeapPssKb
                DalvikHeapRssKb       = $process.DalvikHeapRssKb
                DalvikHeapSizeKb      = $process.DalvikHeapSizeKb
                DalvikHeapAllocKb     = $process.DalvikHeapAllocKb
                DalvikHeapFreeKb      = $process.DalvikHeapFreeKb
                GraphicsPssKb         = $process.GraphicsPssKb
                GraphicsRssKb         = $process.GraphicsRssKb
                CodePssKb             = $process.CodePssKb
                StackPssKb            = $process.StackPssKb
                PrivateOtherPssKb     = $process.PrivateOtherPssKb
                SystemPssKb           = $process.SystemPssKb
                VmRssKb               = $process.VmRssKb
                VmHwmKb               = $process.VmHwmKb
                RssAnonKb             = $process.RssAnonKb
                RssFileKb             = $process.RssFileKb
                VmSwapKb              = $process.VmSwapKb
            }
        }
    )
    if ($processRows.Count -gt 0) {
        if ($processCsvStarted) {
            $processRows | Export-Csv -LiteralPath $ProcessOutputPath -NoTypeInformation -Encoding UTF8 -Append
        } else {
            $processRows | Export-Csv -LiteralPath $ProcessOutputPath -NoTypeInformation -Encoding UTF8
            $processCsvStarted = $true
        }
    }

    if ($null -ne $totalPssKb) {
        $pssMiB = $totalPssKb / 1024.0
        $rssMiB = $totalRssKb / 1024.0
        $powerText = if ($null -ne $battery.DischargePowerMw) { "  Battery {0,7:N1} mW" -f $battery.DischargePowerMw } else { "" }
        Write-Host ("{0,6:N1}s  {1,2} proc  PSS {2,8:N1} MiB  RSS-sum {3,8:N1} MiB{4}" -f ($sampleElapsedMilliseconds / 1000.0), $processes.Count, $pssMiB, $rssMiB, $powerText)
    } else {
        Write-Host ("{0,6:N1}s  {1}" -f ($sampleElapsedMilliseconds / 1000.0), $processState)
    }

    if ($timer.Elapsed.TotalMilliseconds -ge $durationMilliseconds) {
        break
    }

    $sampleIndex++
    $nextSampleMilliseconds += $IntervalMilliseconds
    if ($nextSampleMilliseconds -le $timer.Elapsed.TotalMilliseconds) {
        $nextSampleMilliseconds = [long]$timer.Elapsed.TotalMilliseconds + $IntervalMilliseconds
    }
}

Write-Host "Done. Recorded $($sampleIndex + 1) samples."
Write-Host "Summary CSV: $OutputPath"
Write-Host "Process CSV: $ProcessOutputPath"
