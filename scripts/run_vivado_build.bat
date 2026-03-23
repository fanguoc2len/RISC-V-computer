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
  -source "%SCRIPT_DIR%run_vivado_build.tcl" ^
  -log "%REPO_DIR%\build\vivado_build.log" ^
  -journal "%REPO_DIR%\build\vivado_build.jou"

if errorlevel 1 (
  echo Vivado build FAILED.
  echo Xem log: "%REPO_DIR%\build\vivado_build.log"
  exit /b %errorlevel%
)

echo Vivado build FINISHED.
echo Bitstream du kien nam o:
echo   "%REPO_DIR%\build\vivado\risc_v_computer.runs\impl_1\top_basys3.bit"
echo Log: "%REPO_DIR%\build\vivado_build.log"
