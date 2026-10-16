: << 'BATCH'
@echo off
setlocal

echo ========================================================
echo   MAC Unit All-In-One: Compile, Simulate ^& Launch GTKWave
echo ========================================================
echo.

REM --- Step 1: Compile & Simulate Base MAC ---
echo [1/3] Compiling and running Base MAC simulation...
iverilog -g2005-sv -I rtl/core -o sim_base.vvp rtl/core/full_adder.v rtl/core/half_adder.v rtl/core/compressor_4_2.v rtl/core/carry_counter_overflow.v rtl/core/han_carlson_adder.v rtl/top/mac_base_top.v tb/tb_mac_base.v
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Base MAC compilation failed!
    pause
    exit /b %ERRORLEVEL%
)
vvp sim_base.vvp

echo.
REM --- Step 2: Compile & Simulate Reconfigurable Dual-Mode MAC ---
echo [2/3] Compiling and running Reconfigurable Dual-Mode MAC simulation...
iverilog -g2005-sv -I rtl/core -o sim_reconf.vvp rtl/core/full_adder.v rtl/core/half_adder.v rtl/core/compressor_4_2.v rtl/core/booth_radix4_encoder.v rtl/core/booth_radix4_selector.v rtl/core/carry_counter_overflow.v rtl/core/han_carlson_adder.v rtl/top/mac_reconfigurable_top.v tb/tb_mac_reconfigurable.v
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Reconfigurable MAC compilation failed!
    pause
    exit /b %ERRORLEVEL%
)
vvp sim_reconf.vvp

echo.
REM --- Step 3: Automatically Launch GTKWave ---
echo [3/3] Launching GTKWave GUI Window...
if "%1"=="base" (
    start "" gtkwave mac_base_tb.vcd mac_base_tb.gtkw
) else (
    start "" gtkwave mac_reconfigurable_tb.vcd mac_reconfigurable_tb.gtkw
)

echo.
echo ========================================================
echo   COMPLETE! GTKWave window has been launched.
echo ========================================================
goto :EOF
BATCH

# -----------------------------------------------------------------------------
# Bash Section (Executes automatically when called as: bash run.bat)
# -----------------------------------------------------------------------------
set -e

echo "========================================================"
echo "  MAC Unit All-In-One: Compile, Simulate & Launch GTKWave"
echo "========================================================"
echo ""

echo "[1/3] Compiling and running Base MAC simulation..."
iverilog -g2005-sv -I rtl/core -o sim_base.vvp rtl/core/full_adder.v rtl/core/half_adder.v rtl/core/compressor_4_2.v rtl/core/carry_counter_overflow.v rtl/core/han_carlson_adder.v rtl/top/mac_base_top.v tb/tb_mac_base.v
vvp sim_base.vvp

echo ""
echo "[2/3] Compiling and running Reconfigurable Dual-Mode MAC simulation..."
iverilog -g2005-sv -I rtl/core -o sim_reconf.vvp rtl/core/full_adder.v rtl/core/half_adder.v rtl/core/compressor_4_2.v rtl/core/booth_radix4_encoder.v rtl/core/booth_radix4_selector.v rtl/core/carry_counter_overflow.v rtl/core/han_carlson_adder.v rtl/top/mac_reconfigurable_top.v tb/tb_mac_reconfigurable.v
vvp sim_reconf.vvp

echo ""
echo "[3/3] Launching GTKWave GUI Window..."
if [ "$1" = "base" ]; then
    cmd.exe /c start "" gtkwave mac_base_tb.vcd mac_base_tb.gtkw
else
    cmd.exe /c start "" gtkwave mac_reconfigurable_tb.vcd mac_reconfigurable_tb.gtkw
fi

echo ""
echo "========================================================"
echo "  COMPLETE! GTKWave window has been launched."
echo "========================================================"
