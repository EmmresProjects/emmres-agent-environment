@echo off
setlocal EnableExtensions
cd /d "%~dp0"
where git.exe >nul 2>nul || (echo FAILED: Git unavailable.& pause& exit /b 1)
git rev-parse --is-inside-work-tree >nul 2>nul || (echo FAILED: Initialize this folder as a Git repository first.& pause& exit /b 1)
git lfs install --local || goto :failed
git add . || goto :failed
git diff --cached --quiet
if errorlevel 1 git commit -m "Update Emmre environment knowledge and resources" || goto :failed
git push || goto :failed
echo SUCCESS: Git and LFS push completed.
pause
exit /b 0
:failed
echo FAILED: Exit code %ERRORLEVEL%.
pause
exit /b %ERRORLEVEL%
