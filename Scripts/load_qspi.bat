@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."

set "VITIS_BIN=C:\Xilinx\Vitis\2024.2\bin"
set "PROGRAM_FLASH=%VITIS_BIN%\program_flash.bat"
set "BOOT_IMAGE=%REPO_ROOT%\Releases\BOOT.bin"
set "FSBL=%REPO_ROOT%\Releases\fsbl.elf"
set "FLASH_TYPE=qspi-x4-single"
set "TARGET_ID=2"
set "HW_URL=tcp:127.0.0.1:3121"

if not exist "%PROGRAM_FLASH%" (
    echo program_flash.bat not found: "%PROGRAM_FLASH%"
    exit /b 1
)

if not exist "%BOOT_IMAGE%" (
    echo BOOT.bin not found: "%BOOT_IMAGE%"
    exit /b 1
)

if not exist "%FSBL%" (
    echo FSBL not found: "%FSBL%"
    exit /b 1
)

echo Programming QSPI flash...
echo   BOOT image : "%BOOT_IMAGE%"
echo   FSBL       : "%FSBL%"
echo   Flash type : %FLASH_TYPE%
echo   HW server  : %HW_URL%
echo.
echo Set the board boot mode to JTAG while programming. Switch to QSPI boot after programming.
echo.

"%PROGRAM_FLASH%" ^
  -f "%BOOT_IMAGE%" ^
  -offset 0x0 ^
  -fsbl "%FSBL%" ^
  -flash_type %FLASH_TYPE% ^
  -target_id %TARGET_ID% ^
  -url %HW_URL% ^
  -verify

exit /b %ERRORLEVEL%
