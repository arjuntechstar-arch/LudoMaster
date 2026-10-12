param(
    [int]$Clients = 20,
    [int]$Iterations = 2
)

. (Join-Path $PSScriptRoot 'quality-common.ps1')
Write-QualityHeader 'Load Validation'

Assert-QualityTool 'python'
$env:PYTHONPATH = "$script:RepoRoot;$script:RepoRoot/services/api;$script:RepoRoot/services/realtime"

Invoke-QualityCommand 'REST/API load simulation' 'python' @('tests/e2e_load_test.py','--in-process','--clients',"$Clients",'--iterations',"$Iterations") $script:RepoRoot
Invoke-QualityCommand 'Multiplayer stress simulation' 'python' @('tests/multiplayer/full_game_simulator.py','--games','300','--stress') $script:RepoRoot

Write-Host '[PASS] Load validation complete.'
