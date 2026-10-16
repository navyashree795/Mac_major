@echo off
echo ========================================================
echo   Running MAC Unit Simulation Suite (Icarus Verilog)
echo ========================================================

echo.
echo [1/2] Compiling and running Base MAC Unit Verification...
iverilog -g2005-sv -I rtl/core -o sim_base.vvp rtl/core/full_adder.v rtl/core/half_adder.v rtl/core/compressor_4_2.v rtl/core/carry_counter_overflow.v rtl/core/han_carlson_adder.v rtl/top/mac_base_top.v tb/tb_mac_base.v
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Base MAC compilation failed!
    exit /b %ERRORLEVEL%
)
vvp sim_base.vvp

echo.
echo [2/2] Compiling and running Reconfigurable Dual-Mode MAC Verification...
iverilog -g2005-sv -I rtl/core -o sim_reconf.vvp rtl/core/full_adder.v rtl/core/half_adder.v rtl/core/compressor_4_2.v rtl/core/booth_radix4_encoder.v rtl/core/booth_radix4_selector.v rtl/core/carry_counter_overflow.v rtl/core/han_carlson_adder.v rtl/top/mac_reconfigurable_top.v tb/tb_mac_reconfigurable.v
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Reconfigurable MAC compilation failed!
    exit /b %ERRORLEVEL%
)
vvp sim_reconf.vvp

echo.
echo ========================================================
echo   All Simulations Completed Successfully!
echo   VCD Waveforms generated:
echo     - mac_base_tb.vcd
echo     - mac_reconfigurable_tb.vcd
echo ========================================================
pause
