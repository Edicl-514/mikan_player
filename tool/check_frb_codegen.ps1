# tool/check_frb_codegen.ps1
#
# Verifies that flutter_rust_bridge codegen output for the stable bridge
# layer is reproducible and clean.
#
# Workflow:
#   1. In CI mode (`-RequireClean`), require a clean git working tree.
#   2. Run codegen + cargo fmt twice and compare source/generated snapshots.
#      This works in a normal dirty development tree and proves true
#      second-pass idempotency.
#   3. Run cargo check, cargo fmt --check, and flutter analyze.
#   4. In CI mode, fail if codegen leaves any uncommitted change.
#
# Required by the FRB stable bridge contract documented in
# `docs/frb_api_migration_plan.md`.

[CmdletBinding()]
param(
    [switch]$RequireClean
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

function Invoke-Git {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    Push-Location $repoRoot
    try {
        & git @Arguments
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($exitCode -ne 0) {
        throw "git $($Arguments -join ' ') exited with $exitCode"
    }
}

function Get-GitStatusShort {
    param()
    Push-Location $repoRoot
    try {
        # Only look at worktree changes; staged stuff would be flagged too,
        # but for a codegen smoke check we want the full dirty state.
        $status = & git status --short
    } finally {
        Pop-Location
    }
    # Do not use `return ,$status`: when git has no output, the unary comma
    # wraps `$null` in a one-element array and makes a clean tree look dirty.
    return $status
}

function Invoke-CodegenAndFormat {
    param([Parameter(Mandatory = $true)][string]$PassName)

    Write-Host "[check_frb_codegen] ${PassName}: running flutter_rust_bridge_codegen generate"
    & flutter_rust_bridge_codegen generate
    if ($LASTEXITCODE -ne 0) {
        throw "flutter_rust_bridge_codegen generate exited with $LASTEXITCODE"
    }

    Write-Host "[check_frb_codegen] ${PassName}: running cargo fmt"
    & cargo fmt --manifest-path (Join-Path $repoRoot 'rust/Cargo.toml')
    if ($LASTEXITCODE -ne 0) {
        throw "cargo fmt exited with $LASTEXITCODE"
    }
}

function Get-CodegenSnapshot {
    $roots = @(
        (Join-Path $repoRoot 'rust/src'),
        (Join-Path $repoRoot 'lib/src/rust')
    )

    $entries = foreach ($root in $roots) {
        Get-ChildItem -LiteralPath $root -Recurse -File |
            Sort-Object FullName |
            ForEach-Object {
                # Avoid Path.GetRelativePath so the script also works in
                # Windows PowerShell 5.1 / .NET Framework environments.
                $relativePath = $_.FullName.Substring($repoRoot.Path.Length).TrimStart('\', '/')
                $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                "$relativePath|$hash"
            }
    }

    return @($entries | Sort-Object)
}

Set-Location $repoRoot

# Step 1 — CI can require a clean tree. Local development intentionally
# allows pending source/generated changes so the check can run before commit.
if ($RequireClean) {
    $preStatus = @(Get-GitStatusShort)
    if ($preStatus.Count -gt 0) {
        Write-Error @(
            "Working tree is not clean before check_frb_codegen -RequireClean run."
            "Commit or stash the following changes first:"
            ($preStatus -join "`n")
        ) -ErrorAction Stop
    }
}

# Step 2 — prove second-pass idempotency even when the developer has pending
# changes. The snapshot includes all Rust sources touched by cargo fmt and all
# generated/hand-written Dart bridge files.
Invoke-CodegenAndFormat -PassName 'pass 1'
$snapshot1 = @(Get-CodegenSnapshot)

Invoke-CodegenAndFormat -PassName 'pass 2'
$snapshot2 = @(Get-CodegenSnapshot)

$snapshotDiff = @(Compare-Object -ReferenceObject $snapshot1 -DifferenceObject $snapshot2)
if ($snapshotDiff.Count -gt 0) {
    Write-Error @(
        "The second codegen + cargo fmt pass changed the bridge snapshot:"
        (($snapshotDiff | Out-String).TrimEnd())
    ) -ErrorAction Stop
}

# Step 3 — Rust + Dart compile / lint sanity.
Write-Host "[check_frb_codegen] running cargo check"
& cargo check --manifest-path (Join-Path $repoRoot 'rust/Cargo.toml')
if ($LASTEXITCODE -ne 0) {
    throw "cargo check exited with $LASTEXITCODE"
}

Write-Host "[check_frb_codegen] running cargo fmt --check"
& cargo fmt --check --manifest-path (Join-Path $repoRoot 'rust/Cargo.toml')
if ($LASTEXITCODE -ne 0) {
    throw "cargo fmt --check exited with $LASTEXITCODE"
}

Write-Host "[check_frb_codegen] running flutter analyze"
& flutter analyze
if ($LASTEXITCODE -ne 0) {
    throw "flutter analyze exited with $LASTEXITCODE"
}

# Step 4 — CI mode also verifies that committed generated artifacts are current.
if ($RequireClean) {
    $postStatus = @(Get-GitStatusShort)
    if ($postStatus.Count -gt 0) {
        Write-Error @(
            "check_frb_codegen produced uncommitted changes:"
            ($postStatus -join "`n")
            "Commit the regenerated artifacts or fix the codegen input."
        ) -ErrorAction Stop
    }
}

Write-Host "[check_frb_codegen] OK: codegen is reproducible and checks pass."
