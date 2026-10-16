#!/bin/bash
# ==============================================================================
# Automated PPA Report Generator for MAC Units (NanGate 45nm Flow)
# Modeled identically after the LFSR-NFSR ASIC Project structure.
# Generates separated reports for:
#   reports/synthesis/  -> Area & Standard Cell Utilization (from Yosys stat)
#   reports/signoff/    -> Setup Timing, Hold Timing, Timing Summary, and Power
# ==============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

LIB="lib/NangateOpenCellLibrary_typical.lib"
SDC="scripts/constraints.sdc"
RPT_DIR="reports"

mkdir -p "$RPT_DIR/synthesis" "$RPT_DIR/signoff"

# ------------------------------------------------------------------------------
# 1. AREA & CELL UTILIZATION REPORT (Yosys)
# ------------------------------------------------------------------------------
echo "[1/4] Generating Area & Standard Cell Utilization Reports..."

# Reconfigurable MAC Area Report
{
  echo "============================================================"
  echo "  DESIGN AREA & CELL UTILIZATION REPORT"
  echo "  Design  : mac_reconfigurable_top"
  echo "  Process : NanGate 45nm OpenCellLibrary (typical corner)"
  echo "============================================================"
  echo ""
  yosys -p "read_verilog netlist/mac_reconfigurable_synth.v; stat -liberty $LIB" 2>&1 | awk '/=== mac_reconfigurable_top ===/{flag=1} /End of script/{flag=0} flag'
} > "$RPT_DIR/synthesis/area_utilization_reconfigurable.rpt"

# Base MAC Area Report
{
  echo "============================================================"
  echo "  DESIGN AREA & CELL UTILIZATION REPORT"
  echo "  Design  : mac_base_top"
  echo "  Process : NanGate 45nm OpenCellLibrary (typical corner)"
  echo "============================================================"
  echo ""
  yosys -p "read_verilog netlist/mac_base_synth.v; stat -liberty $LIB" 2>&1 | awk '/=== mac_base_top ===/{flag=1} /End of script/{flag=0} flag'
} > "$RPT_DIR/synthesis/area_utilization_base.rpt"

# Combined Area Report for quick reference
cat "$RPT_DIR/synthesis/area_utilization_reconfigurable.rpt" > "$RPT_DIR/synthesis/area_utilization.rpt"
echo "" >> "$RPT_DIR/synthesis/area_utilization.rpt"
cat "$RPT_DIR/synthesis/area_utilization_base.rpt" >> "$RPT_DIR/synthesis/area_utilization.rpt"

echo "  -> reports/synthesis/area_utilization.rpt"

# ------------------------------------------------------------------------------
# Helper function to run OpenSTA and save report
# ------------------------------------------------------------------------------
run_sta() {
  local top_mod="$1"
  local netlist="$2"
  local tcl_cmds="$3"
  local outfile="$4"
  {
    sta -exit << STAEOF
read_liberty $LIB
read_verilog $netlist
link_design  $top_mod
read_sdc     $SDC
$tcl_cmds
STAEOF
  } > "$outfile" 2>&1
}

# ------------------------------------------------------------------------------
# 2. SETUP TIMING REPORTS (OpenSTA)
# ------------------------------------------------------------------------------
echo "[2/4] Generating Setup Timing Reports..."

run_sta "mac_reconfigurable_top" "netlist/mac_reconfigurable_synth.v" '
puts "============================================================"
puts "  SETUP TIMING REPORT (MAX PATH DELAY)"
puts "  Design: mac_reconfigurable_top  |  Clock: 500 MHz (2.000 ns)"
puts "============================================================"
puts ""
report_checks -path_delay max -format full_clock_expanded -fields {slew cap input_pins nets} -digits 4
puts ""
puts "------------------------------------------------------------"
puts "  Worst Negative Slack (WNS):"
report_worst_slack
report_tns
puts "------------------------------------------------------------"
' "$RPT_DIR/signoff/timing_setup_reconfigurable.rpt"

run_sta "mac_base_top" "netlist/mac_base_synth.v" '
puts "============================================================"
puts "  SETUP TIMING REPORT (MAX PATH DELAY)"
puts "  Design: mac_base_top  |  Clock: 500 MHz (2.000 ns)"
puts "============================================================"
puts ""
report_checks -path_delay max -format full_clock_expanded -fields {slew cap input_pins nets} -digits 4
puts ""
puts "------------------------------------------------------------"
puts "  Worst Negative Slack (WNS):"
report_worst_slack
report_tns
puts "------------------------------------------------------------"
' "$RPT_DIR/signoff/timing_setup_base.rpt"

cat "$RPT_DIR/signoff/timing_setup_reconfigurable.rpt" > "$RPT_DIR/signoff/timing_setup.rpt"
echo "  -> reports/signoff/timing_setup.rpt"

# ------------------------------------------------------------------------------
# 3. HOLD TIMING & TIMING SUMMARY REPORTS (OpenSTA)
# ------------------------------------------------------------------------------
echo "[3/4] Generating Hold & Timing Summary Reports..."

run_sta "mac_reconfigurable_top" "netlist/mac_reconfigurable_synth.v" '
puts "============================================================"
puts "  HOLD TIMING REPORT (MIN PATH DELAY)"
puts "  Design: mac_reconfigurable_top  |  Clock: 500 MHz (2.000 ns)"
puts "============================================================"
puts ""
report_checks -path_delay min -format full_clock_expanded -fields {slew cap input_pins nets} -digits 4
puts ""
puts "------------------------------------------------------------"
puts "  Worst Negative Slack (WNS) Hold:"
report_worst_slack
puts "------------------------------------------------------------"
' "$RPT_DIR/signoff/timing_hold_reconfigurable.rpt"

run_sta "mac_base_top" "netlist/mac_base_synth.v" '
puts "============================================================"
puts "  HOLD TIMING REPORT (MIN PATH DELAY)"
puts "  Design: mac_base_top  |  Clock: 500 MHz (2.000 ns)"
puts "============================================================"
puts ""
report_checks -path_delay min -format full_clock_expanded -fields {slew cap input_pins nets} -digits 4
puts ""
puts "------------------------------------------------------------"
puts "  Worst Negative Slack (WNS) Hold:"
report_worst_slack
puts "------------------------------------------------------------"
' "$RPT_DIR/signoff/timing_hold_base.rpt"

cat "$RPT_DIR/signoff/timing_hold_reconfigurable.rpt" > "$RPT_DIR/signoff/timing_hold.rpt"
echo "  -> reports/signoff/timing_hold.rpt"

# Combined Timing Summary
{
  echo "============================================================"
  echo "  TIMING SUMMARY REPORT (RECONFIGURABLE MAC vs BASE MAC)"
  echo "  Process: NanGate 45nm  |  Target Period: 2.000 ns (500 MHz)"
  echo "============================================================"
  echo ""
  echo "--- Reconfigurable Dual-Mode MAC (mac_reconfigurable_top) ---"
  grep -A 8 "Worst Negative Slack" "$RPT_DIR/signoff/timing_setup_reconfigurable.rpt" || true
  echo ""
  echo "--- Base MAC Unit (mac_base_top - Tung & Huang 2020) ---"
  grep -A 8 "Worst Negative Slack" "$RPT_DIR/signoff/timing_setup_base.rpt" || true
  echo "============================================================"
} > "$RPT_DIR/signoff/timing_summary.rpt"

echo "  -> reports/signoff/timing_summary.rpt"

# ------------------------------------------------------------------------------
# 4. POWER REPORTS (OpenSTA)
# ------------------------------------------------------------------------------
echo "[4/4] Generating Power Estimation Reports..."

run_sta "mac_reconfigurable_top" "netlist/mac_reconfigurable_synth.v" '
puts "============================================================"
puts "  POWER ESTIMATION REPORT"
puts "  Design  : mac_reconfigurable_top  |  NanGate 45nm"
puts "  Voltage : 1.1V  |  Activity: default (0.5 toggle rate)"
puts "============================================================"
puts ""
report_power
puts "============================================================"
' "$RPT_DIR/signoff/power_reconfigurable.rpt"

run_sta "mac_base_top" "netlist/mac_base_synth.v" '
puts "============================================================"
puts "  POWER ESTIMATION REPORT"
puts "  Design  : mac_base_top  |  NanGate 45nm"
puts "  Voltage : 1.1V  |  Activity: default (0.5 toggle rate)"
puts "============================================================"
puts ""
report_power
puts "============================================================"
' "$RPT_DIR/signoff/power_base.rpt"

cat "$RPT_DIR/signoff/power_reconfigurable.rpt" > "$RPT_DIR/signoff/power.rpt"
echo "  -> reports/signoff/power.rpt"

echo "============================================================"
echo "  All PPA Reports Successfully Generated!"
echo "============================================================"
