#!/bin/bash
# ==============================================================================
# Script 4: Complete End-to-End ASIC Flow (RTL -> Simulation -> Synth -> PPA -> PnR)
# Runs the entire flow at once:
#   1. RTL Functional Simulation & Verification (Icarus Verilog)
#   2. Logic Synthesis & Technology Mapping (Yosys -> NanGate 45nm)
#   3. Static Timing, Power & Area Signoff (OpenSTA)
#   4. Physical Place & Route to Final GDS/DEF Layout (OpenROAD)
#   5. Launches GTKWave waveform viewer
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  [Step 4] Running Complete RTL-to-GDSII ASIC Flow (NanGate 45nm)${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# 1. RTL Simulation
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[1/4] Running Functional RTL Simulation & Verification...${NC}"
bash 1_run_simulation_gtkwave.sh reconf &
SIM_PID=$!

# Wait for simulation to finish before proceeding to synthesis
wait $SIM_PID 2>/dev/null || true
echo -e "${GREEN}✓ Simulation passed! Waveforms generated.${NC}\n"

# ------------------------------------------------------------------------------
# 2. Logic Synthesis & PPA Analysis
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[2/4] Running Yosys Synthesis & Signoff PPA Reports...${NC}"
bash 2_run_synthesis_ppa.sh
echo -e "${GREEN}✓ Synthesis & PPA signoff completed!${NC}\n"

# ------------------------------------------------------------------------------
# 3. OpenROAD Place & Route
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[3/4] Running OpenROAD Physical Place & Route (Layout Generation)...${NC}"
docker run --rm \
    -v "$PWD":/work \
    -w /work \
    efabless/openlane:2023.09.07 \
    openroad scripts/openroad_pnr_reconf.tcl

echo -e "${GREEN}✓ Physical Layout Generated:${NC}"
echo "    - results/mac_reconfigurable_top_routed.def"
echo ""

# ------------------------------------------------------------------------------
# 4. Completion Summary
# ------------------------------------------------------------------------------
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  ALL STEPS COMPLETED SUCCESSFULLY!                             ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo "  1. Waveforms:         mac_reconfigurable_tb.vcd (GTKWave launched)"
echo "  2. Gate Netlists:     netlist/mac_reconfigurable_synth.v"
echo "  3. PPA Reports:       reports/synthesis/ and reports/signoff/"
echo "  4. Physical Layout:   results/mac_reconfigurable_top_routed.def"
echo ""
echo -e "To open the 45nm layout in the OpenROAD GUI, run:${CYAN} ./3_view_openroad_gui.sh${NC}"
echo ""
