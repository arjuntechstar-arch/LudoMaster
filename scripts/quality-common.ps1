Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:ResultsRoot = Join-Path $script:RepoRoot 'test-results'

function Initialize-QualityResults {
    if (-not (Test-Path $script:ResultsRoot)) {
        New-Item -ItemType Directory -Path $script:ResultsRoot -Force | Out-Null
    }
}

function Write-QualityHeader {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ''
    Write-Host ('=' * 72)
    Write-Host (" LudoMaster :: {0}" -f $Title)
    Write-Host ('=' * 72)
}

function Assert-QualityTool {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required tool '$Name' was not found in PATH. See docs/12-QUALITY-GATE.md."
    }
}

function Invoke-QualityCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = $script:RepoRoot
    )

    Write-Host "`n[RUN] $Label"
    Push-Location $WorkingDirectory
    try {
        & $Command @Arguments
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }
        if ($exitCode -ne 0) {
            throw "$Label failed with exit code $exitCode."
        }
        Write-Host "[PASS] $Label"
    }
    finally {
        Pop-Location
    }
}

function Test-QualityTool {
    param([Parameter(Mandatory = $true)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

Initialize-QualityResults
