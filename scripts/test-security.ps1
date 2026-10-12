param(
    [switch]$Strict
)

. (Join-Path $PSScriptRoot 'quality-common.ps1')
Write-QualityHeader 'Security Validation'

Assert-QualityTool 'python'
Assert-QualityTool 'npm'

$pathSep = [System.IO.Path]::PathSeparator
$env:PYTHONPATH = @(
    $script:RepoRoot,
    (Join-Path $script:RepoRoot 'services/api'),
    (Join-Path $script:RepoRoot 'services/realtime')
) -join $pathSep

# Scan first-party source only. Low-severity Bandit findings remain visible in
# normal developer scans, while the blocking CI gate is reserved for medium
# and high severity findings to avoid false-positive build failures for token
# labels, enum strings and non-security identifiers.
Invoke-QualityCommand 'Python Bandit scan' 'python' @(
    '-m','bandit','-q','-ll','-r','services/api/app','services/realtime',
    '-x','*/tests/*,*/.venv/*,*/venv/*,*/__pycache__/*,*/build/*,*/dist/*'
) $script:RepoRoot
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
    Invoke-QualityCommand 'Filesystem vulnerability scan (Trivy)' 'trivy' @('fs','--exit-code','1','--severity','HIGH,CRITICAL','--scanners','vuln,secret','--skip-dirs','services/api/.venv','--skip-dirs','apps/admin/node_modules','.') $script:RepoRoot
} elseif ($Strict) {
    throw 'trivy is required in strict security mode.'
} else {
    Write-Host '[WARN] trivy not installed; skipped locally. CI runs it separately.'
}

Write-Host '[PASS] Security validation complete.'
