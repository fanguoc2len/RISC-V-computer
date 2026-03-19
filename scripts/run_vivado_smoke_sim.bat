@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."

if "%VIVADO_BIN%"=="" set "VIVADO_BIN=E:\AMDDesignTools\2025.2\Vivado\bin"

if not exist "%VIVADO_BIN%\vivado.bat" (
  echo ERROR: khong tim thay vivado.bat tai "%VIVADO_BIN%".
  echo Hay set lai bien moi truong VIVADO_BIN neu Vivado nam o cho khac.
  exit /b 1
)

if not exist "%REPO_DIR%\build" mkdir "%REPO_DIR%\build"

call "%VIVADO_BIN%\vivado.bat" -mode batch -notrace ^
  -source "%SCRIPT_DIR%run_vivado_smoke_sim.tcl" ^
  -log "%REPO_DIR%\build\vivado_smoke_sim.log" ^
  -journal "%REPO_DIR%\build\vivado_smoke_sim.jou"

if errorlevel 1 (
  echo Vivado smoke simulation FAILED.
  echo Xem log: "%REPO_DIR%\build\vivado_smoke_sim.log"
  exit /b %errorlevel%
)

findstr /C:"PASS: smoke simulation completed." "%REPO_DIR%\build\vivado_smoke_sim.log" >nul
if errorlevel 1 (
  echo Vivado smoke simulation khong xac nhan duoc PASS.
  echo Xem log: "%REPO_DIR%\build\vivado_smoke_sim.log"
  exit /b 1
)

echo Vivado smoke simulation PASSED.
echo Log: "%REPO_DIR%\build\vivado_smoke_sim.log"
