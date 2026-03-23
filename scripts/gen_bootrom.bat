@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%SCRIPT_DIR%gen_bootrom.py"
  exit /b %errorlevel%
)

where python >nul 2>nul
if not errorlevel 1 (
  python "%SCRIPT_DIR%gen_bootrom.py"
  exit /b %errorlevel%
)

echo ERROR: khong tim thay Python tren may.
echo Hay cai Python hoac chay script bang WSL:
echo   python3 scripts/gen_bootrom.py
exit /b 1
