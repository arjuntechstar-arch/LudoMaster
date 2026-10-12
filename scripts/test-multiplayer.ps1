param(
    [int]$SimulationGames = 200
)

. (Join-Path $PSScriptRoot 'quality-common.ps1')
Write-QualityHeader 'Multiplayer Validation'

Assert-QualityTool 'python'
$pathSep = [System.IO.Path]::PathSeparator
$env:PYTHONPATH = @(
    $script:RepoRoot,
    (Join-Path $script:RepoRoot 'services/api'),
    (Join-Path $script:RepoRoot 'services/realtime')
) -join $pathSep

Invoke-QualityCommand 'Realtime unit/integration suite' 'python' @('-m','pytest','services/realtime/tests','-q') $script:RepoRoot
Invoke-QualityCommand 'Multiplayer simulator' 'python' @('tests/multiplayer/full_game_simulator.py','--games',"$SimulationGames") $script:RepoRoot

Write-Host '[PASS] Multiplayer validation complete.'
