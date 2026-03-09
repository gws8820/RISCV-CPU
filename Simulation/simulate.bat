@echo off
setlocal

set XSIM_DIR=%~dp0..\..\RISCV_CPU.sim\sim_1\behav\xsim
set APP=%~1
if "%APP%"=="" set APP=firmware
set HEX_SRC=%~dp0..\Software\build\%APP%\%APP%.hex

echo === Copying %APP%.hex ===
copy /y "%HEX_SRC%" "%XSIM_DIR%\firmware.hex"
if errorlevel 1 ( echo firmware.hex copy failed: %HEX_SRC% & exit /b 1 )

cd /d "%XSIM_DIR%"

echo === 1/3 Compile ===
call xvlog --incr --relax -L uvm -prj cpu_testbench_vlog.prj -log xvlog.log
if errorlevel 1 ( echo Compile failed & exit /b 1 )

echo === 2/3 Elaborate ===
call xelab --incr --debug typical --relax --mt 2 -L xil_defaultlib -L uvm -L unisims_ver -L unimacro_ver -L secureip --snapshot cpu_testbench_behav xil_defaultlib.cpu_testbench xil_defaultlib.glbl -log elaborate.log
if errorlevel 1 ( echo Elaborate failed & exit /b 1 )

echo === 3/3 Simulate ===
xsim cpu_testbench_behav --runall --log simulate.log
