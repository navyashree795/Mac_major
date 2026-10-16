#!/bin/bash
# ==============================================================================
# Script 2: Yosys RTL Synthesis & Signoff PPA Analysis (NanGate 45nm)
# Maps RTL designs to standard cells and generates separated Power, Area,
# and Timing reports identical to the LFSR-NFSR ASIC Project structure.
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

mkdir -p netlist results reports

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  [Step 2] Yosys Synthesis & Signoff PPA Analysis (NanGate 45nm) ${NC}"
echo -e "${BLUE}================================================================${NC}"

# --- Part 1: Yosys Synthesis ---
echo -e "\n${YELLOW}[1/2] Running Yosys Logic Synthesis on NanGate 45nm...${NC}"
if command -v yosys &> /dev/null; then
    yosys scripts/synth_nangate45.ys
else
    wsl bash -c "cd '$SCRIPT_DIR' && yosys scripts/synth_nangate45.ys"
fi

echo -e "${GREEN}✓ Synthesis Complete! Gate netlists written to:${NC}"
echo "    - netlist/mac_base_synth.v"
echo "    - netlist/mac_reconfigurable_synth.v"

# --- Part 2: PPA Analysis (Power, Area, Timing) ---
echo -e "\n${YELLOW}[2/2] Generating Separated PPA Reports (OpenSTA & Yosys Stat)...${NC}"
bash scripts/gen_ppa_reports.sh

echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}  Step 2 Complete! All PPA Reports saved in reports/ folder:    ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo "  reports/"
echo "  ├── synthesis/"
echo "  │   ├── area_utilization.rpt             (Combined area & cell count)"
echo "  │   ├── area_utilization_reconfigurable.rpt"
echo "  │   └── area_utilization_base.rpt"
echo "  └── signoff/"
echo "      ├── power.rpt                        (Internal, switching, leakage power)"
echo "      ├── power_reconfigurable.rpt"
echo "      ├── power_base.rpt"
echo "      ├── timing_setup.rpt                 (Critical path delay & setup slack)"
echo "      ├── timing_setup_reconfigurable.rpt"
echo "      ├── timing_setup_base.rpt"
echo "      ├── timing_hold.rpt                  (Hold slack & min paths)"
echo "      └── timing_summary.rpt               (WNS & TNS summary)"
echo ""
