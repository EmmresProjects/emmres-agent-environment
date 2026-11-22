# Portable, folder-only Windows toolkit. No WinGet, admin rights, IDEs, emulators, or images.
# Run from an extracted folder. Everything is placed under .\Emmres_Environment.
[CmdletBinding()]
param([string]$Root = '')

# Windows PowerShell 5.1 can evaluate parameter defaults before $PSScriptRoot is ready.
# Resolve the script directory after parameter binding instead.
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
  $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
  $ScriptDir = (Get-Location).Path
}
if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = Join-Path (Split-Path -Parent $ScriptDir) 'Local Environment'
}
$Root = [IO.Path]::GetFullPath($Root)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Tools = Join-Path $Root 'tools'; $Bin = Join-Path $Root 'bin'; $Tmp = Join-Path $Root '_downloads'
$PyHome = Join-Path $Root 'python'; $Venv = Join-Path $Root 'venv'; $Cache = Join-Path $Root 'cache'
@($Root,$Tools,$Bin,$Tmp,$PyHome,$Cache,(Join-Path $Root 'workspace'),(Join-Path $Root 'logs'),(Join-Path $Root 'skills'),(Join-Path $Root 'config'),(Join-Path $Root 'scripts'),(Join-Path $Root 'models')) | ForEach-Object { New-Item -ItemType Directory -Force $_ | Out-Null }
Start-Transcript -Path (Join-Path $Root 'logs\build.log') -Append | Out-Null

function Section($s){ Write-Host "`n=== $s ===" -ForegroundColor Cyan }
function Download($url,$out){
  Write-Host "Download: $url"
  $partial = "$out.part"
  Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
  $headers = @{ 'User-Agent'='Emmres-Portable-Environment/10.1'; 'Accept'='*/*' }
  $lastError = $null
  for($attempt=1; $attempt -le 4; $attempt++){
    try {
      Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $url -OutFile $partial -TimeoutSec 300
      if(-not (Test-Path $partial) -or (Get-Item $partial).Length -lt 1024){ throw 'Downloaded file is missing or unexpectedly small.' }
      Move-Item -LiteralPath $partial -Destination $out -Force
      return
    } catch {
      $lastError = $_
      Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
      Write-Warning "Download attempt $attempt of 4 failed: $($_.Exception.Message)"
      if($attempt -lt 4){ Start-Sleep -Seconds ([Math]::Pow(2,$attempt)) }
    }
  }
  $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
  if($curl){
    Write-Host 'Retrying with curl.exe...'
    & $curl.Source --fail --location --retry 5 --retry-all-errors --connect-timeout 30 --max-time 1800 --output $partial $url
    if($LASTEXITCODE -eq 0 -and (Test-Path $partial) -and (Get-Item $partial).Length -ge 1024){
      Move-Item -LiteralPath $partial -Destination $out -Force
      return
    }
  }
  Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
  throw "Download failed after retries: $url. Last error: $($lastError.Exception.Message)"
}
function Expand-ZipClean($zip,$dest){ if(Test-Path $dest){Remove-Item $dest -Recurse -Force}; New-Item -ItemType Directory -Force $dest|Out-Null; Expand-Archive $zip $dest -Force }
function GitHubAsset($repo,$pattern,$out){
  $h=@{'User-Agent'='Emmres-Portable-Environment'}
  $r=Invoke-RestMethod -Headers $h -Uri "https://api.github.com/repos/$repo/releases/latest"
  $a=$r.assets | Where-Object {$_.name -match $pattern} | Select-Object -First 1
  if(!$a){throw "No release asset matching $pattern in $repo"}; Download $a.browser_download_url $out
}
function Flatten-OneFolder($dir){
  $items=Get-ChildItem $dir -Force; if($items.Count -eq 1 -and $items[0].PSIsContainer){
    $inner=$items[0].FullName; Get-ChildItem $inner -Force | Move-Item -Destination $dir -Force; Remove-Item $inner -Force
  }
}
function Shim($name,$target,$prefix=''){
  $content="@echo off`r`n`"$target`" $prefix %*`r`n"
  Set-Content -Encoding ASCII -Path (Join-Path $Bin "$name.cmd") -Value $content
}

try {
  Section 'uv and managed portable Python'
  $uvZip=Join-Path $Tmp 'uv.zip'; GitHubAsset 'astral-sh/uv' 'x86_64-pc-windows-msvc\.zip$' $uvZip
  $uvDir=Join-Path $Tools 'uv'; Expand-ZipClean $uvZip $uvDir; Flatten-OneFolder $uvDir
  $env:UV_PYTHON_INSTALL_DIR=$PyHome; $env:UV_CACHE_DIR=Join-Path $Cache 'uv'; $env:UV_TOOL_DIR=Join-Path $Tools 'uv-tools'
  $uv=(Get-ChildItem $uvDir -Filter uv.exe -Recurse | Select-Object -First 1).FullName
  # Install the managed runtime if missing. uv may report that its global launcher already exists; that is harmless.
  & $uv python install 3.12
  if($LASTEXITCODE -ne 0){ throw 'Managed Python 3.12 installation failed.' }

  $venvPython = Join-Path $Venv 'Scripts\python.exe'
  if(Test-Path -LiteralPath $venvPython){
    Write-Host "Reusing existing virtual environment: $Venv" -ForegroundColor Green
    & $venvPython --version
    if($LASTEXITCODE -ne 0){ throw 'Existing virtual environment Python is not usable.' }
  } else {
    Write-Host "Creating virtual environment: $Venv"
    & $uv venv --python 3.12 $Venv
    if($LASTEXITCODE -ne 0){ throw 'Virtual environment creation failed.' }
  }
  # Install or update required packages without clearing the existing environment.
  & $uv pip install --python $venvPython pip setuptools wheel
  & $uv pip install --python $venvPython -r (Join-Path $ScriptDir 'portable_requirements_v10.txt')
  & $venvPython -m pip --version
  & $uv pip install --python $venvPython --upgrade 'kokoro-onnx==0.6.1' 'onnxruntime>=1.20,<2' 'soundfile>=0.12,<1' 'protobuf==5.29.6'
  if($LASTEXITCODE -ne 0){ throw 'Required modern Kokoro voice runtime installation failed.' }
  & $uv pip install --python $venvPython --reinstall 'protobuf==5.29.6'
  if($LASTEXITCODE -ne 0){ throw 'Compatible protobuf pin failed.' }

  Section 'Portable Node.js for coding, agents, and WebDev'
  $nodeZip=Join-Path $Tmp 'node.zip'
  $nodeIndex=Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json'
  $nodeVersion=($nodeIndex | Where-Object {$_.lts -and ($_.files -contains 'win-x64-zip')} | Select-Object -First 1).version
  if(!$nodeVersion){ throw 'Could not resolve the current Node.js LTS Windows ZIP.' }
  Download "https://nodejs.org/dist/$nodeVersion/node-$nodeVersion-win-x64.zip" $nodeZip
  Expand-ZipClean $nodeZip (Join-Path $Tools 'node'); Flatten-OneFolder (Join-Path $Tools 'node')

  Section 'Android Platform Tools: adb and fastboot, no emulator images'
  $ptZip=Join-Path $Tmp 'platform-tools.zip'; Download 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' $ptZip
  Expand-ZipClean $ptZip (Join-Path $Tools 'android'); Flatten-OneFolder (Join-Path $Tools 'android')

  Section 'FFmpeg and FFprobe'
  $ffZip=Join-Path $Tmp 'ffmpeg.zip'; Download 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' $ffZip
  Expand-ZipClean $ffZip (Join-Path $Tools 'ffmpeg'); Flatten-OneFolder (Join-Path $Tools 'ffmpeg')

  Section 'Portable Java runtime for APKTool'
  $jreZip=Join-Path $Tmp 'jre.zip'
  Download 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jre/hotspot/normal/eclipse' $jreZip
  Expand-ZipClean $jreZip (Join-Path $Tools 'java'); Flatten-OneFolder (Join-Path $Tools 'java')

  Section 'APKTool'
  $apkJar=Join-Path $Tools 'apktool\apktool.jar'; New-Item -ItemType Directory -Force (Split-Path $apkJar)|Out-Null
  GitHubAsset 'iBotPeaches/Apktool' '^apktool_.*\.jar$' $apkJar

  Section 'Portable Git, 7-Zip, jq, yq, ripgrep and fd'
  $git=Join-Path $Tmp 'git.7z.exe'; GitHubAsset 'git-for-windows/git' 'PortableGit-.*-64-bit\.7z\.exe$' $git
  $gitDir=Join-Path $Tools 'git'; New-Item -ItemType Directory -Force $gitDir|Out-Null; & $git -y -o"$gitDir" | Out-Null
  $seven=Join-Path $Tmp '7zr.exe'; Download 'https://www.7-zip.org/a/7zr.exe' $seven; Copy-Item $seven (Join-Path $Bin '7zr.exe') -Force
  GitHubAsset 'jqlang/jq' '^jq-windows-amd64\.exe$' (Join-Path $Bin 'jq.exe')
  GitHubAsset 'mikefarah/yq' '^yq_windows_amd64\.exe$' (Join-Path $Bin 'yq.exe')
  $rgZip=Join-Path $Tmp 'rg.zip'; GitHubAsset 'BurntSushi/ripgrep' 'x86_64-pc-windows-msvc\.zip$' $rgZip; Expand-ZipClean $rgZip (Join-Path $Tools 'ripgrep'); Flatten-OneFolder (Join-Path $Tools 'ripgrep')
  $fdZip=Join-Path $Tmp 'fd.zip'; GitHubAsset 'sharkdp/fd' 'x86_64-pc-windows-msvc\.zip$' $fdZip; Expand-ZipClean $fdZip (Join-Path $Tools 'fd'); Flatten-OneFolder (Join-Path $Tools 'fd')

  Section 'Standard offline neural voice model'
  $voiceDir=Join-Path $Root 'models\voice\kokoro'; New-Item -ItemType Directory -Force $voiceDir | Out-Null
  # Kokoro ONNX INT8 is the compact standard model. The voice bank provides several stable voices.
  Download 'https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1/kokoro-v1.0.int8.onnx' (Join-Path $voiceDir 'kokoro-v1.0.int8.onnx')
  Download 'https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1/voices-v1.0.bin' (Join-Path $voiceDir 'voices-v1.0.bin')

  @'
import argparse
from pathlib import Path
import soundfile as sf
from kokoro_onnx import Kokoro

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "models" / "voice" / "kokoro" / "kokoro-v1.0.int8.onnx"
VOICES = ROOT / "models" / "voice" / "kokoro" / "voices-v1.0.bin"
# Expressive presets use stable voices plus pace. They are style presets, not guaranteed emotion control.
PRESETS = {
    "neutral": ("af_heart", 1.00),
    "warm": ("af_bella", 0.96),
    "bright": ("af_nova", 1.08),
    "calm": ("af_sarah", 0.88),
    "serious": ("am_michael", 0.90),
    "energetic": ("am_puck", 1.15),
    "narrator": ("bm_george", 0.92),
}
p=argparse.ArgumentParser(description="Offline Kokoro neural speech")
p.add_argument("text")
p.add_argument("-o","--output",default="speech.wav")
p.add_argument("--style",choices=PRESETS,default="neutral")
p.add_argument("--voice")
p.add_argument("--speed",type=float)
p.add_argument("--lang",default="en-us")
a=p.parse_args()
voice,speed=PRESETS[a.style]
voice=a.voice or voice; speed=a.speed or speed
k=Kokoro(str(MODEL),str(VOICES))
samples,rate=k.create(a.text,voice=voice,speed=speed,lang=a.lang)
sf.write(a.output,samples,rate)
print(a.output)
'@ | Set-Content -Encoding UTF8 (Join-Path $Root 'scripts\speak.py')

  @'
@echo off
"%~dp0..\venv\Scripts\python.exe" "%~dp0speak.py" %*
'@ | Set-Content -Encoding ASCII (Join-Path $Root 'scripts\speak.cmd')

  Section 'Including supplied Skills Catalogs'
  $catalogSource=Join-Path $ScriptDir 'Skills_Catalogs.xml'
  if(Test-Path $catalogSource){
    Copy-Item $catalogSource (Join-Path $Root 'skills\Skills_Catalogs.xml') -Force
    $catalogZip = Join-Path $Tmp 'Skills_Catalogs.zip'
    Copy-Item $catalogSource $catalogZip -Force
    Expand-Archive -LiteralPath $catalogZip -DestinationPath (Join-Path $Root 'skills\catalogs') -Force
  } else { Write-Warning 'Skills_Catalogs.xml was not found beside the builder.' }

  Section 'Creating stable command shims'
  Shim 'node' (Join-Path $Tools 'node\node.exe'); Shim 'npm' (Join-Path $Tools 'node\npm.cmd'); Shim 'npx' (Join-Path $Tools 'node\npx.cmd')
  Shim 'python' (Join-Path $Venv 'Scripts\python.exe'); Shim 'pip' (Join-Path $Venv 'Scripts\python.exe') '-m pip'
  Shim 'uv' $uv; Shim 'uvx' (Join-Path (Split-Path $uv) 'uvx.exe')
  Shim 'adb' (Join-Path $Tools 'android\adb.exe'); Shim 'fastboot' (Join-Path $Tools 'android\fastboot.exe')
  Shim 'ffmpeg' (Join-Path $Tools 'ffmpeg\bin\ffmpeg.exe'); Shim 'ffprobe' (Join-Path $Tools 'ffmpeg\bin\ffprobe.exe')
  Shim 'java' (Join-Path $Tools 'java\bin\java.exe'); Shim 'apktool' (Join-Path $Tools 'java\bin\java.exe') "-jar `"$apkJar`""
  Shim 'git' (Join-Path $Tools 'git\cmd\git.exe'); Shim 'rg' (Join-Path $Tools 'ripgrep\rg.exe'); Shim 'fd' (Join-Path $Tools 'fd\fd.exe')

  Copy-Item (Join-Path $ScriptDir 'portable_requirements_v10.txt') (Join-Path $Root 'portable_requirements_v10.txt') -Force
  Set-Content -Encoding UTF8 (Join-Path $Root 'venv\built_at.txt') -Value $Root

  @"
@echo off
set "EMMRES_ENV=%~dp0"
set "PATH=%EMMRES_ENV%bin;%EMMRES_ENV%venv\Scripts;%EMMRES_ENV%tools\node;%PATH%"
set "JAVA_HOME=%EMMRES_ENV%tools\java"
set "ANDROID_HOME=%EMMRES_ENV%tools\android"
set "ANDROID_SDK_ROOT=%EMMRES_ENV%tools\android"
set "UV_PYTHON_INSTALL_DIR=%EMMRES_ENV%python"
set "UV_CACHE_DIR=%EMMRES_ENV%cache\uv"
set "PIP_CACHE_DIR=%EMMRES_ENV%cache\pip"
for /f "usebackq delims=" %%P in ("%EMMRES_ENV%venv\built_at.txt") do set "BUILT_AT=%%P"
if /i not "%BUILT_AT%"=="%EMMRES_ENV:~0,-1%" (
  echo Environment moved. Rebuilding its Python venv for this path...
  rmdir /s /q "%EMMRES_ENV%venv"
  "%EMMRES_ENV%tools\uv\uv.exe" venv --python 3.12 "%EMMRES_ENV%venv"
  "%EMMRES_ENV%tools\uv\uv.exe" pip install --python "%EMMRES_ENV%venv\Scripts\python.exe" pip setuptools wheel
  "%EMMRES_ENV%tools\uv\uv.exe" pip install --python "%EMMRES_ENV%venv\Scripts\python.exe" -r "%EMMRES_ENV%portable_requirements_v10.txt"
  "%EMMRES_ENV%tools\uv\uv.exe" pip install --python "%EMMRES_ENV%venv\Scripts\python.exe" --reinstall "protobuf==5.29.6"
  >"%EMMRES_ENV%venv\built_at.txt" echo %EMMRES_ENV:~0,-1%
)
cd /d "%EMMRES_ENV%workspace"
echo Emmre's Environment active.
cmd /k
"@ | Set-Content -Encoding ASCII (Join-Path $Root 'Open_Environment.cmd')

  @'
# Add provider keys only if you use hosted models. Keep this file private.
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
GOOGLE_API_KEY=
AZURE_OPENAI_API_KEY=
AZURE_OPENAI_ENDPOINT=
GITHUB_TOKEN=
BRAVE_SEARCH_API_KEY=
TAVILY_API_KEY=
'@ | Set-Content -Encoding ASCII (Join-Path $Root 'config\.env.example')

  @"
# Emmre's Portable Agent Studio
Run Open_Environment.cmd. Tools remain inside this folder and do not require WinGet or administrator rights.
Included: Python 3.12 venv, uv/uvx, portable Node.js LTS/npm/npx, FFmpeg/FFprobe, adb/fastboot, APKTool with Java 17, portable Git, 7zr, jq, yq, ripgrep, fd, agent SDKs, media/document/vision/3D libraries, and the supplied Skills Catalogs.
Excluded: Android Studio, SDK platforms/build-tools, emulators, system images, IDEs, Docker, model weights, and caches from the final package.
"@ | Set-Content -Encoding UTF8 (Join-Path $Root 'README.md')

  Section 'Verification'
  $env:PATH="$Bin;$Venv\Scripts;$env:PATH"
  $tests=@('node --version','npm --version','python --version','pip --version','ffmpeg -version','adb version','fastboot --version','apktool --version','git --version','jq --version','yq --version','rg --version','fd --version','7zr')
  $results=@(); $failed=@()
  foreach($t in $tests){
    $oldPreference=$ErrorActionPreference; $ErrorActionPreference='Continue'
    $output = & $env:ComSpec /d /c "$t 2>&1"
    $code=$LASTEXITCODE; $ErrorActionPreference=$oldPreference
    $first=($output | Select-Object -First 1)
    $results += "$t`t$code`t$first"
    if($code -ne 0){ $failed += $t }
  }
  $results | Set-Content -Encoding UTF8 (Join-Path $Root 'logs\verification.tsv')
  & (Join-Path $Venv 'Scripts\python.exe') -m pip check
  if($LASTEXITCODE -ne 0){ throw 'Python dependency verification failed.' }
  $voiceProbePath = Join-Path $Root 'scripts\verify_kokoro.py'
  @'
from importlib.metadata import version
from pathlib import Path
from kokoro_onnx import Kokoro
import sys
root = Path(sys.argv[1])
model = root / "models" / "voice" / "kokoro" / "kokoro-v1.0.int8.onnx"
voices = root / "models" / "voice" / "kokoro" / "voices-v1.0.bin"
print("kokoro-onnx", version("kokoro-onnx"))
k = Kokoro(str(model), str(voices))
print("voices", len(k.get_voices()))
'@ | Set-Content -Encoding UTF8 $voiceProbePath
  & (Join-Path $Venv 'Scripts\python.exe') $voiceProbePath $Root
  if($LASTEXITCODE -ne 0){ throw 'Kokoro binary voice-bank compatibility check failed.' }
  & (Join-Path $Venv 'Scripts\python.exe') (Join-Path $Root 'scripts\speak.py') 'Environment voice test.' --style neutral -o (Join-Path $Root 'logs\voice_test.wav')
  if($LASTEXITCODE -ne 0){ throw 'Offline neural voice verification failed.' }
  if($LASTEXITCODE -ne 0){ throw 'Python dependency verification failed. See logs\build.log.' }
  if($failed.Count -gt 0){ throw "Tool verification failed: $($failed -join ', '). See logs\verification.tsv." }

  Section 'Generating agent-readable installed environment inventory'
  & (Join-Path $Venv 'Scripts\python.exe') (Join-Path $ScriptDir 'Scripts\generate_environment_manifest.py') $ScriptDir
  if($LASTEXITCODE -ne 0){ throw 'Installed environment manifest generation failed.' }
  & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir 'Scripts\Publish_Agent_Knowledge.ps1')
  if($LASTEXITCODE -ne 0){ throw 'Environment installed, but agent-readable file publication failed.' }
  # Run the generator with the exact virtual-environment interpreter. Do not use py.exe or PATH launchers,
  # because Windows launchers can retain stale paths and fail when a parent folder contains an apostrophe.
  & $venvPython (Join-Path $ScriptDir 'Scripts\build_documentation.py')
  if($LASTEXITCODE -ne 0){ throw 'Environment installed, but documentation and index generation failed.' }

  Remove-Item $Tmp -Recurse -Force
  Write-Host "`nREADY: $Root" -ForegroundColor Green
  Write-Host 'Open Open_Environment.cmd to give CMD and agents access to every bundled tool.'
} finally { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null }
