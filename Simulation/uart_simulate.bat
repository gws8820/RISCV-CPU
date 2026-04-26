@echo off
setlocal

set ROOT=%~dp0..
set XSIM_DIR=%~dp0uart_xsim

if not exist "%XSIM_DIR%" mkdir "%XSIM_DIR%"
cd /d "%XSIM_DIR%"

echo === 1/3 Compile UART testbench ===
call xvlog --sv --incr --relax ^
    -i "%ROOT%\RTL\Core" ^
    -i "%ROOT%\RTL\UART" ^
    "%ROOT%\RTL\Core\riscv_defines.sv" ^
    "%ROOT%\RTL\UART\uart_defines.sv" ^
    "%ROOT%\RTL\Core\memory_init_interface.sv" ^
    "%ROOT%\RTL\Core\mmio_out_interface.sv" ^
    "%ROOT%\RTL\Core\mmio_in_interface.sv" ^
    "%ROOT%\RTL\UART\uart_baud_gen.sv" ^
    "%ROOT%\RTL\UART\uart_rx_phy.sv" ^
    "%ROOT%\RTL\UART\uart_rx_ctrl.sv" ^
    "%ROOT%\RTL\UART\uart_tx_phy.sv" ^
    "%ROOT%\RTL\UART\uart_tx_ctrl.sv" ^
    "%ROOT%\RTL\UART\uart_controller.sv" ^
    "%ROOT%\RTL\Testbench\uart_testbench.sv" ^
    -log xvlog_uart.log
if errorlevel 1 ( echo Compile failed & exit /b 1 )

echo === 2/3 Elaborate ===
call xelab --incr --debug typical --relax --mt 2 ^
    -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip ^
    --snapshot uart_testbench_behav work.uart_testbench ^
    -log elaborate_uart.log
if errorlevel 1 ( echo Elaborate failed & exit /b 1 )

echo === 3/3 Simulate ===
call xsim uart_testbench_behav --runall --log simulate_uart.log
if errorlevel 1 ( echo Simulate failed & exit /b 1 )
findstr /c:"Fatal:" /c:"[FAIL]" simulate_uart.log >nul
if not errorlevel 1 ( echo Simulate failed & exit /b 1 )

echo UART simulation passed.
