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
