@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Build and Publish Emmre Environment
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build_Emmres_Agent_Studio_v10.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo SUCCESS: Local Environment updated, resources published, and documentation rebuilt.
) else (
  echo FAILED: Exit code %RC%. Check ..\Local Environment\logs\build.log
)
pause
exit /b %RC%
