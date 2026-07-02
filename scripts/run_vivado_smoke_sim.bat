@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."

call "%SCRIPT_DIR%resolve_vivado_bin.bat" || exit /b 1

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
