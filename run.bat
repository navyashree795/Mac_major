: << 'BATCH'
@echo off
setlocal

if "%1"=="1" goto DO_ALL
if "%1"=="2" goto DO_SYNTH_PPA
if "%1"=="3" goto DO_GUI
if "%1"=="4" goto DO_COMPLETE
if "%1"=="synth" goto DO_SYNTH
if "%1"=="ppa" goto DO_PPA
if "%1"=="reports" goto DO_PPA
if "%1"=="pnr" goto DO_PNR
if "%1"=="base" goto DO_BASE
if "%1"=="reconf" goto DO_RECONF
goto DO_ALL

:DO_ALL
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
start "" gtkwave mac_reconfigurable_tb.vcd mac_reconfigurable_tb.gtkw

echo.
echo ========================================================
echo   COMPLETE! GTKWave window has been launched.
echo ========================================================
goto :EOF

:DO_BASE
start "" gtkwave mac_base_tb.vcd mac_base_tb.gtkw
goto :EOF

:DO_RECONF
start "" gtkwave mac_reconfigurable_tb.vcd mac_reconfigurable_tb.gtkw
goto :EOF

:DO_SYNTH
echo ========================================================
echo   Running Yosys Synthesis on Nangate 45nm Library
echo ========================================================
wsl bash -c "cd '/mnt/c/Users/WIN10/Desktop/my projects 1/Mac_major' && yosys -l synth.log scripts/synth_nangate45.ys"
echo.
echo [DONE] Gate-level netlists generated in netlist/ folder:
echo   - netlist/mac_base_synth.v
echo   - netlist/mac_reconfigurable_synth.v
goto :EOF

:DO_PPA
echo ========================================================
echo   Generating NanGate 45nm PPA Reports (Power, Area, Timing)
echo ========================================================
wsl bash -c "cd '/mnt/c/Users/WIN10/Desktop/my projects 1/Mac_major' && bash scripts/gen_ppa_reports.sh"
echo.
echo [DONE] All PPA Reports saved to reports/ folder:
echo   - reports/synthesis/area_utilization.rpt
echo   - reports/signoff/power.rpt
echo   - reports/signoff/timing_setup.rpt
echo   - reports/signoff/timing_hold.rpt
echo   - reports/signoff/timing_summary.rpt
goto :EOF

:DO_SYNTH_PPA
echo ========================================================
echo   Running Yosys Synthesis ^& Generating PPA Reports
echo ========================================================
wsl bash -c "cd '/mnt/c/Users/WIN10/Desktop/my projects 1/Mac_major' && yosys -l synth.log scripts/synth_nangate45.ys && bash scripts/gen_ppa_reports.sh"
echo.
echo [DONE] Synthesis and PPA reports generated in reports/ folder!
goto :EOF

:DO_GUI
echo ========================================================
echo   Launching OpenROAD 45nm Layout GUI
echo ========================================================
docker run --rm -it --net=host -e DISPLAY="%DISPLAY%" -v /tmp/.X11-unix:/tmp/.X11-unix -v "%CD%":/work -w /work efabless/openlane:2023.09.07 openroad -gui scripts/load_reconf_gui.tcl
goto :EOF

:DO_COMPLETE
echo ========================================================
echo   Running Complete Flow (Sim + Synth + PPA + PnR)
echo ========================================================
wsl bash -c "cd '/mnt/c/Users/WIN10/Desktop/my projects 1/Mac_major' && bash 4_run_complete_flow.sh"
goto :EOF

:DO_PNR
echo ========================================================
echo   Running OpenROAD Physical Layout Place ^& Route (45nm)
echo ========================================================
docker run --rm -v "%CD%":/work -w /work efabless/openlane:2023.09.07 openroad scripts/openroad_pnr_reconf.tcl
echo.
echo [DONE] 45nm Chip Layout Generated:
echo   - results/mac_reconfigurable_top_routed.def
goto :EOF
BATCH

# -----------------------------------------------------------------------------
# Bash Section (Executes automatically when called as: bash run.bat)
# -----------------------------------------------------------------------------
set -e

case "$1" in
    1|sim)
        bash 1_run_simulation_gtkwave.sh "$2"
        exit 0
        ;;
    2|synth|ppa|reports)
        bash 2_run_synthesis_ppa.sh
        exit 0
        ;;
    3|gui|layout)
        bash 3_view_openroad_gui.sh "$2"
        exit 0
        ;;
    4|all|flow)
        bash 4_run_complete_flow.sh
        exit 0
        ;;
    pnr)
        docker run --rm -v "$PWD":/work -w /work efabless/openlane:2023.09.07 openroad scripts/openroad_pnr_reconf.tcl
        exit 0
        ;;
esac

# Default: Run simulation and launch GTKWave
bash 1_run_simulation_gtkwave.sh
