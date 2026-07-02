@echo off
setlocal

set "RESOLVED_VIVADO_BIN=%VIVADO_BIN%"

if not "%RESOLVED_VIVADO_BIN%"=="" goto validate

if defined XILINX_VIVADO if exist "%XILINX_VIVADO%\bin\vivado.bat" (
  set "RESOLVED_VIVADO_BIN=%XILINX_VIVADO%\bin"
  goto validate
)

for %%I in (vivado.bat) do if not "%%~$PATH:I"=="" (
  set "RESOLVED_VIVADO_BIN=%%~dp$PATH:I"
  goto validate
)

if exist "E:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat" (
  set "RESOLVED_VIVADO_BIN=E:\AMDDesignTools\2025.2\Vivado\bin"
  goto validate
)

echo ERROR: khong tim thay vivado.bat.
echo Co the sua bang mot trong cac cach sau:
echo   1. set VIVADO_BIN=duong-dan-toi-thu-muc-bin-cua-Vivado
echo   2. set XILINX_VIVADO=duong-dan-goc-cai-dat-Vivado
echo   3. them Vivado vao PATH
exit /b 1

:validate
if not exist "%RESOLVED_VIVADO_BIN%\vivado.bat" (
  echo ERROR: khong tim thay vivado.bat tai "%RESOLVED_VIVADO_BIN%".
  echo Hay set lai VIVADO_BIN hoac XILINX_VIVADO cho dung.
  exit /b 1
)

endlocal & set "VIVADO_BIN=%RESOLVED_VIVADO_BIN%"
exit /b 0
