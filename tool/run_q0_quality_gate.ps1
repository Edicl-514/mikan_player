# tool/run_q0_quality_gate.ps1
#
# Runs the local Q-0 quality gate. CI integration is intentionally kept out of
# this script; callers decide when and where to invoke it.

[CmdletBinding()]
param(
    [switch]$Coverage,
    [switch]$CheckFrbCodegen
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$rustManifest = Join-Path $repoRoot 'rust/Cargo.toml'

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @()
    )

    Write-Host "[q0] $Label"
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command $($Arguments -join ' ') exited with $LASTEXITCODE"
    }
}

function Show-DartCoverageSummary {
    $lcovPath = Join-Path $repoRoot 'coverage/lcov.info'
    if (-not (Test-Path -LiteralPath $lcovPath)) {
        throw "Dart coverage file was not generated: $lcovPath"
    }

    $records = @()
    $current = $null
    foreach ($line in Get-Content -LiteralPath $lcovPath) {
        if ($line.StartsWith('SF:')) {
            $current = [ordered]@{
                Path = $line.Substring(3).Replace('/', '\')
                Found = 0
                Hit = 0
            }
        } elseif ($null -ne $current -and $line.StartsWith('LF:')) {
            $current.Found = [int]$line.Substring(3)
        } elseif ($null -ne $current -and $line.StartsWith('LH:')) {
            $current.Hit = [int]$line.Substring(3)
        } elseif ($line -eq 'end_of_record' -and $null -ne $current) {
            $isGenerated =
                $current.Path -like 'lib\gen\*' -or
                $current.Path -like 'lib\src\rust\*' -or
                $current.Path -like '*.g.dart'
            if (-not $isGenerated) {
                $records += [pscustomobject]$current
            }
            $current = $null
        }
    }

    $found = ($records | Measure-Object -Property Found -Sum).Sum
    $hit = ($records | Measure-Object -Property Hit -Sum).Sum
    $percent = if ($found -gt 0) { [math]::Round(100 * $hit / $found, 2) } else { 0 }
    Write-Host "[q0] Dart coverage: $hit/$found lines ($percent%), $($records.Count) files"
}

function Get-CargoLlvmCovPath {
    $localTool = Join-Path $repoRoot 'build/q0-tools/bin/cargo-llvm-cov.exe'
    if (Test-Path -LiteralPath $localTool) {
        return $localTool
    }

    $installedTool = Get-Command cargo-llvm-cov -ErrorAction SilentlyContinue
    if ($null -ne $installedTool) {
        return $installedTool.Source
    }

    throw @"
cargo-llvm-cov is required for -Coverage.
Install it locally without changing project dependencies:
  rustup component add llvm-tools-preview
  cargo install cargo-llvm-cov --locked --root build/q0-tools
"@
}

function Show-RustCoverageSummary {
    param([Parameter(Mandatory = $true)][string]$JsonPath)

    $report = Get-Content -Raw -LiteralPath $JsonPath | ConvertFrom-Json
    $totals = $report.data[0].totals
    $linePercent = [math]::Round([double]$totals.lines.percent, 2)
    $functionPercent = [math]::Round([double]$totals.functions.percent, 2)
    Write-Host (
        '[q0] Rust coverage: {0}/{1} lines ({2}%), {3}/{4} functions ({5}%)' -f
        $totals.lines.covered,
        $totals.lines.count,
        $linePercent,
        $totals.functions.covered,
        $totals.functions.count,
        $functionPercent
    )
}

Push-Location $repoRoot
try {
    Invoke-CheckedCommand -Label 'Generating Flutter localizations' -Command 'flutter' -Arguments @('gen-l10n')
    Invoke-CheckedCommand -Label 'Scanning for hard-coded UI text' -Command 'dart' -Arguments @(
        'run',
        'tool/scan_hardcoded_ui_text.dart',
        '--fail-on-findings'
    )
    Invoke-CheckedCommand -Label 'Running Flutter analyzer' -Command 'flutter' -Arguments @('analyze')

    if ($Coverage) {
        Invoke-CheckedCommand -Label 'Running Flutter tests with coverage' -Command 'flutter' -Arguments @(
            'test',
            '--coverage',
            '--no-pub'
        )
        Show-DartCoverageSummary
    } else {
        Invoke-CheckedCommand -Label 'Running Flutter tests' -Command 'flutter' -Arguments @(
            'test',
            '--no-pub'
        )
    }

    Invoke-CheckedCommand -Label 'Checking Rust formatting' -Command 'cargo' -Arguments @(
        'fmt',
        '--manifest-path',
        $rustManifest,
        '--',
        '--check'
    )

    if ($Coverage) {
        $cargoLlvmCov = Get-CargoLlvmCovPath
        $rustCoveragePath = Join-Path $repoRoot 'build/q0-rust-coverage.json'
        Invoke-CheckedCommand -Label 'Running Rust tests with coverage' -Command $cargoLlvmCov -Arguments @(
            'llvm-cov',
            '--manifest-path',
            $rustManifest,
            '--json',
            '--summary-only',
            '--output-path',
            $rustCoveragePath,
            '--ignore-filename-regex',
            '(frb_generated\.rs|build\.rs)',
            '--quiet'
        )
        Show-RustCoverageSummary -JsonPath $rustCoveragePath
    } else {
        Invoke-CheckedCommand -Label 'Running Rust tests' -Command 'cargo' -Arguments @(
            'test',
            '--manifest-path',
            $rustManifest
        )
    }

    if ($CheckFrbCodegen) {
        $frbCheck = Join-Path $repoRoot 'tool/check_frb_codegen.ps1'
        Write-Host '[q0] Checking FRB code generation reproducibility'
        & $frbCheck
        if ($LASTEXITCODE -ne 0) {
            throw "check_frb_codegen.ps1 exited with $LASTEXITCODE"
        }
    }
} finally {
    Pop-Location
}

Write-Host '[q0] OK: local Q-0 quality gate passed.'
