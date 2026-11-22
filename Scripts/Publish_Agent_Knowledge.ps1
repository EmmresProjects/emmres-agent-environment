[CmdletBinding()]
param([string]$RepositoryRoot = '')
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$Local = Join-Path (Split-Path -Parent $RepositoryRoot) 'Local Environment'
$Resources = Join-Path $RepositoryRoot 'resources'
$OutputDirectory = Join-Path $RepositoryRoot 'docs\downloads\environment'

if (-not (Test-Path -LiteralPath $Local)) {
    throw "Local Environment not found: $Local"
}
New-Item -ItemType Directory -Force -Path $Resources, $OutputDirectory | Out-Null
Get-ChildItem -LiteralPath $Resources -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

$ReadableExtensions = @(
    '.txt','.md','.json','.jsonl','.csv','.tsv','.xml','.yaml','.yml','.toml',
    '.ini','.cfg','.conf','.py','.ps1','.cmd','.bat','.js','.mjs','.cjs','.ts',
    '.html','.css','.sql','.sh','.srt','.vtt'
)
$BinaryExtensions = @(
    '.onnx','.bin','.safetensors','.pt','.pth','.gguf','.tflite','.wasm',
    '.jar','.exe','.dll','.pyd','.zip','.7z'
)
$BlockedDirectoryNames = @('venv','cache','_downloads','node_modules','.git','workspace','logs')
$LfsMaximumBytes = 2GB
$Records = @()
$Skipped = @()

$Files = Get-ChildItem -LiteralPath $Local -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName
foreach ($File in $Files) {
    $RelativePath = $File.FullName.Substring($Local.Length)
    $RelativePath = $RelativePath.TrimStart([char[]]@('\','/'))
    $Parts = $RelativePath -split '[\\/]'

    $IsBlocked = $false
    foreach ($Part in $Parts) {
        if ($BlockedDirectoryNames -contains $Part) {
            $IsBlocked = $true
            break
        }
    }
    if ($IsBlocked) { continue }

    $Extension = $File.Extension.ToLowerInvariant()
    if ($ReadableExtensions -contains $Extension) {
        $Kind = 'readable'
    } elseif ($BinaryExtensions -contains $Extension) {
        $Kind = 'binary'
    } else {
        continue
    }

    if ($File.Length -gt $LfsMaximumBytes) {
        $Skipped += [pscustomobject]@{
            relativePath = $RelativePath.Replace('\','/')
            bytes = $File.Length
            reason = 'exceeds-2GiB-lfs-limit'
        }
        Write-Warning "Skipped over-2GiB file: $RelativePath"
        continue
    }

    $Destination = Join-Path $Resources $RelativePath
    $DestinationDirectory = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
    Copy-Item -LiteralPath $File.FullName -Destination $Destination -Force

    $Records += [pscustomobject]@{
        name = $File.Name
        relativePath = $RelativePath.Replace('\','/')
        repositoryPath = ('resources/' + $RelativePath.Replace('\','/'))
        kind = $Kind
        extension = $Extension
        bytes = $File.Length
        category = $(if ($Parts.Count -gt 1) { $Parts[0] } else { 'root' })
        agentReadable = ($Kind -eq 'readable')
        downloadable = $true
        storage = $(if ($Kind -eq 'binary') { 'git-lfs' } else { 'git' })
    }
}

$Publication = [ordered]@{
    schemaVersion = '2.1'
    source = '../Local Environment'
    repository = 'Emmres_Environment'
    files = $Records
    skipped = $Skipped
    notes = @(
        'Readable files are searchable knowledge.',
        'ONNX and selected binary assets are downloadable through Git LFS but are not text-searchable.',
        'Binary files up to 2 GiB are accepted for Git LFS publication.'
    )
}
$Publication | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'published-files.json') -Encoding UTF8
Write-Host "Copied $($Records.Count) accepted files into repository resources. Skipped $($Skipped.Count)." -ForegroundColor Green
