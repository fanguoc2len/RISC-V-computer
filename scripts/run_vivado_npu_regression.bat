@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."

call "%SCRIPT_DIR%resolve_vivado_bin.bat" || exit /b 1

if not exist "%REPO_DIR%\build" mkdir "%REPO_DIR%\build"

call "%VIVADO_BIN%\vivado.bat" -mode batch -notrace ^
  -source "%SCRIPT_DIR%run_vivado_npu_regression.tcl" ^
  -log "%REPO_DIR%\build\vivado_npu_regression.log" ^
  -journal "%REPO_DIR%\build\vivado_npu_regression.jou"

if errorlevel 1 (
  echo Vivado NPU regression FAILED.
  echo Xem log: "%REPO_DIR%\build\vivado_npu_regression.log"
  exit /b %errorlevel%
)

findstr /C:"npu_regression_status=PASS" "%REPO_DIR%\build\npu_regression_status.txt" >nul
if errorlevel 1 (
  echo Vivado NPU regression khong xac nhan duoc PASS.
  echo Xem:
  echo   "%REPO_DIR%\build\vivado_npu_regression.log"
  echo   "%REPO_DIR%\build\npu_regression_status.txt"
  exit /b 1
)

echo Vivado NPU regression PASSED.
echo Summary: "%REPO_DIR%\build\npu_regression_status.txt"
echo Log: "%REPO_DIR%\build\vivado_npu_regression.log"
