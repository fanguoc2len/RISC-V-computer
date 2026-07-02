@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."

call "%SCRIPT_DIR%resolve_vivado_bin.bat" || exit /b 1

if not exist "%REPO_DIR%\build" mkdir "%REPO_DIR%\build"

call "%VIVADO_BIN%\vivado.bat" -mode batch -notrace ^
  -source "%SCRIPT_DIR%run_vivado_monitor_sim.tcl" ^
  -log "%REPO_DIR%\build\vivado_monitor_sim.log" ^
  -journal "%REPO_DIR%\build\vivado_monitor_sim.jou"

if errorlevel 1 (
  echo Vivado monitor shell simulation FAILED.
  echo Xem log: "%REPO_DIR%\build\vivado_monitor_sim.log"
  exit /b %errorlevel%
)

findstr /C:"PASS: monitor shell simulation completed." "%REPO_DIR%\build\vivado_monitor_sim.log" >nul
if errorlevel 1 (
  echo Vivado monitor shell simulation khong xac nhan duoc PASS.
  echo Xem log: "%REPO_DIR%\build\vivado_monitor_sim.log"
  exit /b 1
)

echo Vivado monitor shell simulation PASSED.
echo Log: "%REPO_DIR%\build\vivado_monitor_sim.log"
