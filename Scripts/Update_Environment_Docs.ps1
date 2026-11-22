[CmdletBinding()]
param([string]$RepositoryRoot = '')
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$LocalEnvironment = Join-Path (Split-Path -Parent $RepositoryRoot) 'Local Environment'
$Python = Join-Path $LocalEnvironment 'venv\Scripts\python.exe'
$Generator = Join-Path $PSScriptRoot 'build_documentation.py'

if (-not (Test-Path -LiteralPath $Python)) {
    throw "Installed Python was not found: $Python"
}
if (-not (Test-Path -LiteralPath $Generator)) {
    throw "Documentation generator was not found: $Generator"
}

Write-Host "Using documentation Python: $Python"
& $Python $Generator
if ($LASTEXITCODE -ne 0) {
    throw "Documentation generator failed with exit code $LASTEXITCODE."
}
exit 0
