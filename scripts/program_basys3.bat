@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."

call "%SCRIPT_DIR%resolve_vivado_bin.bat" || exit /b 1

if not exist "%REPO_DIR%\build\vivado\risc_v_computer.runs\impl_1\top_basys3.bit" (
  echo ERROR: Chua co bitstream. Hay chay scripts\run_vivado_build.bat truoc.
  exit /b 1
)

call "%VIVADO_BIN%\vivado.bat" -mode batch -notrace ^
  -source "%SCRIPT_DIR%program_basys3.tcl" ^
  -log "%REPO_DIR%\build\program_basys3.log" ^
  -journal "%REPO_DIR%\build\program_basys3.jou"

if errorlevel 1 (
  echo Program board FAILED.
  echo Xem log: "%REPO_DIR%\build\program_basys3.log"
  exit /b %errorlevel%
)

echo Program board FINISHED.
echo Log: "%REPO_DIR%\build\program_basys3.log"
