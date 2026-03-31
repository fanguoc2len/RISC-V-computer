@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."

if exist "%SCRIPT_DIR%gen_offline_demo_data.py" (
  where py >nul 2>nul
  if not errorlevel 1 (
    py -3 "%SCRIPT_DIR%gen_offline_demo_data.py" >nul 2>nul
  ) else (
    where python >nul 2>nul
    if not errorlevel 1 (
      python "%SCRIPT_DIR%gen_offline_demo_data.py" >nul 2>nul
    )
  )
)

if not exist "%REPO_DIR%\demo\index.html" (
  echo ERROR: khong tim thay offline demo tai "%REPO_DIR%\demo\index.html".
  exit /b 1
)

start "" "%REPO_DIR%\demo\index.html"
echo Offline demo da duoc mo.
