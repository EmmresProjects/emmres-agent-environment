[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Update_Installed_Environment.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Git_LFS_Push.ps1')
exit $LASTEXITCODE
