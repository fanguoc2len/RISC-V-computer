@echo off
setlocal

if "%~2"=="" (
  echo Usage: scripts\gen_raw_boot_image.bat payload.bin output.img [--load-addr 0x10000000] [--entry-addr 0x10000000]
  exit /b 1
)

set "SCRIPT_DIR=%~dp0"

where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%SCRIPT_DIR%gen_raw_boot_image.py" %*
  exit /b %errorlevel%
)

where python >nul 2>nul
if not errorlevel 1 (
  python "%SCRIPT_DIR%gen_raw_boot_image.py" %*
  exit /b %errorlevel%
)

echo ERROR: khong tim thay Python tren may.
echo Hay cai Python hoac chay script bang WSL:
echo   python3 scripts/gen_raw_boot_image.py payload.bin output.img
exit /b 1
