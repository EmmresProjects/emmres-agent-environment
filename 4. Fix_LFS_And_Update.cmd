@echo off
setlocal EnableExtensions
title Emmre's Environment - Fix Git LFS and Update

cd /d "%~dp0"

echo ============================================================
echo  Emmre's Environment - Git LFS Repair
echo ============================================================
echo.

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo FAILED: Place this CMD file in the repository root.
    goto :failed
)

echo [1/8] Initializing Git LFS...
git lfs install --local
if errorlevel 1 goto :failed

echo [2/8] Adding generated directories to .gitignore...
call :AddIgnore "Components/Emmres_Environment/cache/"
call :AddIgnore "Components/Emmres_Environment/venv/"

echo [3/8] Removing generated directories from the Git index...
echo       Local files will not be deleted.
git rm -r --cached --ignore-unmatch -- "Components/Emmres_Environment/cache"
if errorlevel 1 goto :failed

git rm -r --cached --ignore-unmatch -- "Components/Emmres_Environment/venv"
if errorlevel 1 goto :failed

echo [4/8] Configuring Git LFS tracking...
git lfs track "Components/Emmres_Environment/models/**/*.onnx"
if errorlevel 1 goto :failed

git lfs track "Components/Emmres_Environment/tools/ffmpeg/bin/*.exe"
if errorlevel 1 goto :failed

echo [5/8] Re-indexing intentional large files through Git LFS...
git rm --cached --ignore-unmatch -- "Components/Emmres_Environment/models/voice/kokoro/kokoro-v1.0.int8.onnx"
if errorlevel 1 goto :failed

git rm --cached --ignore-unmatch -- "Components/Emmres_Environment/tools/ffmpeg/bin/ffmpeg.exe"
if errorlevel 1 goto :failed

git rm --cached --ignore-unmatch -- "Components/Emmres_Environment/tools/ffmpeg/bin/ffplay.exe"
if errorlevel 1 goto :failed

git rm --cached --ignore-unmatch -- "Components/Emmres_Environment/tools/ffmpeg/bin/ffprobe.exe"
if errorlevel 1 goto :failed

git add -- ".gitignore" ".gitattributes"
if errorlevel 1 goto :failed

call :AddIfExists "Components/Emmres_Environment/models/voice/kokoro/kokoro-v1.0.int8.onnx"
if errorlevel 1 goto :failed

call :AddIfExists "Components/Emmres_Environment/tools/ffmpeg/bin/ffmpeg.exe"
if errorlevel 1 goto :failed

call :AddIfExists "Components/Emmres_Environment/tools/ffmpeg/bin/ffplay.exe"
if errorlevel 1 goto :failed

call :AddIfExists "Components/Emmres_Environment/tools/ffmpeg/bin/ffprobe.exe"
if errorlevel 1 goto :failed

echo [6/8] Staging remaining repository changes...
git add -A
if errorlevel 1 goto :failed

echo [7/8] Verifying Git LFS configuration...
call :RequireLFS "Components/Emmres_Environment/models/voice/kokoro/kokoro-v1.0.int8.onnx"
if errorlevel 1 goto :failed

call :RequireLFS "Components/Emmres_Environment/tools/ffmpeg/bin/ffmpeg.exe"
if errorlevel 1 goto :failed

call :RequireLFS "Components/Emmres_Environment/tools/ffmpeg/bin/ffplay.exe"
if errorlevel 1 goto :failed

call :RequireLFS "Components/Emmres_Environment/tools/ffmpeg/bin/ffprobe.exe"
if errorlevel 1 goto :failed

echo.
echo Files currently tracked by Git LFS:
git lfs ls-files
if errorlevel 1 goto :failed

echo.
echo Current Git status:
git status --short
if errorlevel 1 goto :failed

echo.
echo [8/8] Running the environment documentation updater...
if not exist "%CD%\Scripts\Update_Environment_Docs.ps1" (
    echo FAILED: Scripts\Update_Environment_Docs.ps1 was not found.
    goto :failed
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CD%\Scripts\Update_Environment_Docs.ps1"
if errorlevel 1 goto :failed

echo.
echo ============================================================
echo  SUCCESS: Git LFS repair and documentation update completed.
echo ============================================================
echo.
echo You can now rerun your normal One_Click_Update_And_Push command.
echo.
pause
exit /b 0

:AddIgnore
if not exist ".gitignore" type nul > ".gitignore"
findstr /L /X /C:"%~1" ".gitignore" >nul 2>&1
if errorlevel 1 >>".gitignore" echo %~1
exit /b 0

:AddIfExists
if exist "%~1" (
    git add -- "%~1"
    exit /b %errorlevel%
)
echo       SKIPPED: "%~1" does not exist.
exit /b 0

:RequireLFS
if not exist "%~1" (
    echo       SKIPPED: "%~1" does not exist.
    exit /b 0
)
git check-attr filter -- "%~1" | findstr /L /C:"filter: lfs" >nul
if errorlevel 1 (
    echo FAILED: File is not configured for Git LFS:
    echo         %~1
    exit /b 1
)
echo       VERIFIED: %~1
exit /b 0

:failed
set "EXIT_CODE=%errorlevel%"
if "%EXIT_CODE%"=="0" set "EXIT_CODE=1"
echo.
echo ============================================================
echo  FAILED: Exit code %EXIT_CODE%
echo ============================================================
echo.
echo No local cache, virtual environment, model, or FFmpeg file
echo was physically deleted. Review the message shown above.
echo.
pause
exit /b %EXIT_CODE%
