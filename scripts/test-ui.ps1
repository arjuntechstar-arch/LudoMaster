param()

. (Join-Path $PSScriptRoot 'quality-common.ps1')
Write-QualityHeader 'UI Validation'

Assert-QualityTool 'flutter'
Invoke-QualityCommand 'Flutter widget and responsive tests' 'flutter' @('test','test/ui_quality_test.dart','--reporter=expanded') (Join-Path $script:RepoRoot 'apps/mobile')
Invoke-QualityCommand 'Flutter full widget suite' 'flutter' @('test','--reporter=compact') (Join-Path $script:RepoRoot 'apps/mobile')

if (Test-Path (Join-Path $script:RepoRoot 'apps/admin/package.json')) {
    Assert-QualityTool 'npm'
    Invoke-QualityCommand 'Admin production build' 'npm' @('run','build') (Join-Path $script:RepoRoot 'apps/admin')
}

Write-Host '[PASS] UI validation complete.'
