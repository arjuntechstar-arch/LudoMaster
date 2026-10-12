param(
    [ValidateSet('Quick','Full','Security','Multiplayer','UI','Load')]
    [string]$Mode = 'Quick'
)

. (Join-Path $PSScriptRoot 'quality-common.ps1')

Write-QualityHeader "Quality Gate ($Mode)"
$failures = New-Object System.Collections.Generic.List[string]

function Invoke-Stage {
    param([string]$Name, [scriptblock]$Action)
    try {
        & $Action
    }
    catch {
        $failures.Add("$Name :: $($_.Exception.Message)")
        Write-Host "[FAIL] $Name"
        Write-Host $_.Exception.Message
    }
}

if ($Mode -in @('Quick','Full')) {
    Invoke-Stage 'Game engine analysis' {
        Assert-QualityTool 'dart'
        Invoke-QualityCommand 'Dart analyze' 'dart' @('analyze') (Join-Path $script:RepoRoot 'packages/game_engine')
    }
    Invoke-Stage 'Game engine tests' {
        Invoke-QualityCommand 'Dart engine tests' 'dart' @('test','--reporter=expanded') (Join-Path $script:RepoRoot 'packages/game_engine')
    }
    Invoke-Stage 'Backend and realtime tests' {
        Assert-QualityTool 'python'
        $pathSep = [System.IO.Path]::PathSeparator
        $env:PYTHONPATH = @(
            $script:RepoRoot,
            (Join-Path $script:RepoRoot 'services/api'),
            (Join-Path $script:RepoRoot 'services/realtime')
        ) -join $pathSep
        Invoke-QualityCommand 'Backend API tests' 'python' @('-m','pytest','services/api/tests','-q') $script:RepoRoot
        Invoke-QualityCommand 'Realtime tests' 'python' @('-m','pytest','services/realtime/tests','-q') $script:RepoRoot
    }
    Invoke-Stage 'Flutter analysis and tests' {
        Assert-QualityTool 'flutter'
        Invoke-QualityCommand 'Flutter analyze' 'flutter' @('analyze','--no-fatal-infos') (Join-Path $script:RepoRoot 'apps/mobile')
        Invoke-QualityCommand 'Flutter tests' 'flutter' @('test','--reporter=expanded') (Join-Path $script:RepoRoot 'apps/mobile')
    }
    Invoke-Stage 'Admin validation' {
        Assert-QualityTool 'npm'
        Invoke-QualityCommand 'Admin npm ci' 'npm' @('ci') (Join-Path $script:RepoRoot 'apps/admin')
        Invoke-QualityCommand 'Admin production build' 'npm' @('run','build') (Join-Path $script:RepoRoot 'apps/admin')
    }
}

if ($Mode -in @('Security','Full')) {
    Invoke-Stage 'Security checks' { & (Join-Path $PSScriptRoot 'test-security.ps1') }
}
if ($Mode -in @('Multiplayer','Full')) {
    Invoke-Stage 'Multiplayer checks' { & (Join-Path $PSScriptRoot 'test-multiplayer.ps1') }
}
if ($Mode -in @('UI','Full')) {
    Invoke-Stage 'UI checks' { & (Join-Path $PSScriptRoot 'test-ui.ps1') }
}
if ($Mode -in @('Load','Full')) {
    Invoke-Stage 'Load checks' { & (Join-Path $PSScriptRoot 'test-load.ps1') }
}

$summary = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    mode = $Mode
    passed = ($failures.Count -eq 0)
    failures = $failures
}
$summary | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $script:ResultsRoot 'quality-gate.json') -Encoding UTF8

if ($failures.Count -gt 0) {
    Write-Host "`nQUALITY GATE: FAILED"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host "`nQUALITY GATE: PASS"
exit 0
