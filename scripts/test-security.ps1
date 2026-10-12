param(
    [switch]$Strict
)

. (Join-Path $PSScriptRoot 'quality-common.ps1')
Write-QualityHeader 'Security Validation'

Assert-QualityTool 'python'
Assert-QualityTool 'npm'

$env:PYTHONPATH = "$script:RepoRoot;$script:RepoRoot/services/api;$script:RepoRoot/services/realtime"

Invoke-QualityCommand 'Python Bandit scan' 'python' @('-m','bandit','-q','-r','services/api','services/realtime','-x','*/tests/*') $script:RepoRoot
Invoke-QualityCommand 'API dependency audit' 'python' @('-m','pip_audit','-r','services/api/requirements.txt') $script:RepoRoot
Invoke-QualityCommand 'Admin npm ci' 'npm' @('ci') (Join-Path $script:RepoRoot 'apps/admin')
Invoke-QualityCommand 'Admin npm audit' 'npm' @('audit','--audit-level=high') (Join-Path $script:RepoRoot 'apps/admin')
Invoke-QualityCommand 'API security regression tests' 'python' @('-m','pytest','tests/security','-q') $script:RepoRoot

if (Test-QualityTool 'gitleaks') {
    Invoke-QualityCommand 'Secret scan (gitleaks)' 'gitleaks' @('detect','--source','.','--no-git','--redact') $script:RepoRoot
} elseif ($Strict) {
    throw 'gitleaks is required in strict security mode.'
} else {
    Write-Host '[WARN] gitleaks not installed; skipped locally. CI runs secret scanning separately.'
}

if (Test-QualityTool 'trivy') {
    Invoke-QualityCommand 'Filesystem vulnerability scan (Trivy)' 'trivy' @('fs','--exit-code','1','--severity','HIGH,CRITICAL','--scanners','vuln,secret','.') $script:RepoRoot
} elseif ($Strict) {
    throw 'trivy is required in strict security mode.'
} else {
    Write-Host '[WARN] trivy not installed; skipped locally. CI runs it separately.'
}

Write-Host '[PASS] Security validation complete.'
