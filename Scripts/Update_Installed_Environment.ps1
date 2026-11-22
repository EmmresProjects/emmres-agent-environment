[CmdletBinding()]
param([switch]$SkipDocumentation)
$ErrorActionPreference='Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Builder = Join-Path $Repo 'Build_Emmres_Agent_Studio_v10.ps1'
if (-not (Test-Path $Builder)) { throw "Builder not found: $Builder" }
& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Builder
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not $SkipDocumentation) {
  & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Publish_Agent_Knowledge.ps1')
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Update_Environment_Docs.ps1')
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
$python = Join-Path $Repo 'Emmres_Environment\venv\Scripts\python.exe'
if (Test-Path $python) {
  & $python -m pip check
  if ($LASTEXITCODE -ne 0) { throw 'pip check failed after update.' }
}
Write-Host 'Environment update completed successfully.' -ForegroundColor Green
