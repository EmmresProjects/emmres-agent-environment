@echo off
setlocal EnableExtensions
title Emmre Environment - Git LFS Repair V2
cd /d "%~dp0"

echo ============================================================
echo  Git LFS Repair V2 - covers scanner-visible cache and venv
 echo ============================================================
echo.

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  echo FAILED: Put this file in the repository root.
  goto :failed
)

git lfs install --local
if errorlevel 1 goto :failed

rem Keep generated directories out of normal Git commits.
call :AddIgnore "Components/Emmres_Environment/cache/"
call :AddIgnore "Components/Emmres_Environment/venv/"

git rm -r --cached --ignore-unmatch -- "Components/Emmres_Environment/cache" >nul 2>&1
git rm -r --cached --ignore-unmatch -- "Components/Emmres_Environment/venv" >nul 2>&1

rem The one-click checker scans physical files, including ignored files.
rem Therefore all large binary types in this component need LFS attributes.
echo Configuring LFS attributes...
git lfs track "Components/Emmres_Environment/**/*.onnx"
if errorlevel 1 goto :failed
git lfs track "Components/Emmres_Environment/**/*.exe"
if errorlevel 1 goto :failed
git lfs track "Components/Emmres_Environment/**/*.dll"
if errorlevel 1 goto :failed
git lfs track "Components/Emmres_Environment/**/*.pyd"
if errorlevel 1 goto :failed

git add -- .gitattributes .gitignore
if errorlevel 1 goto :failed

rem Re-add only intentional repository assets. Cache and venv stay ignored.
call :ReAdd "Components/Emmres_Environment/models/voice/kokoro/kokoro-v1.0.int8.onnx"
if errorlevel 1 goto :failed
call :ReAdd "Components/Emmres_Environment/tools/ffmpeg/bin/ffmpeg.exe"
if errorlevel 1 goto :failed
call :ReAdd "Components/Emmres_Environment/tools/ffmpeg/bin/ffplay.exe"
if errorlevel 1 goto :failed
call :ReAdd "Components/Emmres_Environment/tools/ffmpeg/bin/ffprobe.exe"
if errorlevel 1 goto :failed

rem Check every file reported by the current failure log.
echo.
echo Verifying reported files...
call :Check "Components/Emmres_Environment/cache/uv/archive-v0/0AvQOAoavEmX4J4a/torch/lib/torch_cpu.dll"
if errorlevel 1 goto :failed
call :Check "Components/Emmres_Environment/cache/uv/archive-v0/3ZCyE0urrzrYwSlP/llvmlite/binding/llvmlite.dll"
if errorlevel 1 goto :failed
call :Check "Components/Emmres_Environment/cache/uv/archive-v0/7cQ2rkDVJBz5cY9x/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v9.0.2.exe"
if errorlevel 1 goto :failed
call :Check "Components/Emmres_Environment/cache/uv/archive-v0/D5o82H5uXlAMt7N1/_polars_runtime_32/_polars_runtime.pyd"
if errorlevel 1 goto :failed
call :Check "Components/Emmres_Environment/cache/uv/archive-v0/hKE4PT3tqVWd1Zp6/open3d/Open3D.dll"
if errorlevel 1 goto :failed
call :Check "Components/Emmres_Environment/venv/Lib/site-packages/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v9.0.2.exe"
if errorlevel 1 goto :failed
call :Check "Components/Emmres_Environment/venv/Lib/site-packages/llvmlite/binding/llvmlite.dll"
if errorlevel 1 goto :failed
call :Check "Components/Emmres_Environment/venv/Lib/site-packages/open3d/Open3D.dll"
if errorlevel 1 goto :failed
call :Check "Components/Emmres_Environment/venv/Lib/site-packages/torch/lib/torch_cpu.dll"
if errorlevel 1 goto :failed
call :Check "Components/Emmres_Environment/venv/Lib/site-packages/_polars_runtime_32/_polars_runtime.pyd"
if errorlevel 1 goto :failed

echo.
echo Git status:
git status --short

echo.
echo ============================================================
echo  SUCCESS: Every reported file is covered by Git LFS rules.
echo ============================================================
echo Now run your normal One_Click_Update_And_Push file.
echo.
pause
exit /b 0

:AddIgnore
if not exist ".gitignore" type nul > ".gitignore"
findstr /L /X /C:"%~1" ".gitignore" >nul 2>&1
if errorlevel 1 >>".gitignore" echo %~1
exit /b 0

:ReAdd
if not exist "%~1" exit /b 0
git rm --cached --ignore-unmatch -- "%~1" >nul 2>&1
git add -f -- "%~1"
exit /b %errorlevel%

:Check
if not exist "%~1" (
  echo SKIPPED missing: %~1
  exit /b 0
)
for /f "tokens=3" %%A in ('git check-attr filter -- "%~1"') do set "ATTR=%%A"
if /I not "%ATTR%"=="lfs" (
  echo FAILED not covered: %~1
  exit /b 1
)
echo VERIFIED: %~1
set "ATTR="
exit /b 0

:failed
set "RC=%errorlevel%"
if "%RC%"=="0" set "RC=1"
echo.
echo FAILED with exit code %RC%.
echo No local cache or venv files were deleted.
pause
exit /b %RC%
