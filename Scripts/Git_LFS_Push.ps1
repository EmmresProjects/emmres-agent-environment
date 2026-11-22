[CmdletBinding()]
param([string]$Message = '')
$ErrorActionPreference='Stop'
$Repo = Split-Path -Parent $PSScriptRoot
Set-Location $Repo
& git rev-parse --is-inside-work-tree | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'This folder is not a Git repository.' }
if (Get-Command git-lfs -ErrorAction SilentlyContinue) { & git lfs install --local; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }
& git add --all
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$pending = & git status --porcelain
if ($pending) {
  if ([string]::IsNullOrWhiteSpace($Message)) { $Message = 'Update Emmre agent environment ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') }
  & git commit -m $Message
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else { Write-Host 'No changes to commit.' }
& git push
exit $LASTEXITCODE
