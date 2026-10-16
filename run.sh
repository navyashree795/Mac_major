#!/bin/bash
# ==============================================================================
# Complete 1-Click Execution Manager: MAC Major Project (NanGate 45nm Flow)
#
# Available Options:
#   ./run.sh 1   (or ./1_run_simulation_gtkwave.sh) : Simulation & GTKWave waveforms
#   ./run.sh 2   (or ./2_run_synthesis_ppa.sh)      : Yosys synthesis & PPA reports
#   ./run.sh 3   (or ./3_view_openroad_gui.sh)      : OpenROAD 45nm layout GUI
#   ./run.sh 4   (or ./4_run_complete_flow.sh)      : Complete flow all at once
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

case "$1" in
    1|sim|waves)
        bash 1_run_simulation_gtkwave.sh "$2"
        ;;
    2|synth|ppa|reports)
        bash 2_run_synthesis_ppa.sh
        ;;
    3|gui|layout)
        bash 3_view_openroad_gui.sh "$2"
        ;;
    4|all|flow)
        bash 4_run_complete_flow.sh
        ;;
    pnr)
        echo -e "${BLUE}Running OpenROAD PnR...${NC}"
        docker run --rm -v "$PWD":/work -w /work efabless/openlane:2023.09.07 openroad scripts/openroad_pnr_reconf.tcl
        ;;
    base)
        bash 1_run_simulation_gtkwave.sh base
        ;;
    reconf)
        bash 1_run_simulation_gtkwave.sh reconf
        ;;
    *)
        echo -e "${BLUE}================================================================${NC}"
        echo -e "${BLUE}  MAC Major Project: NanGate 45nm RTL-to-GDSII ASIC Flow        ${NC}"
        echo -e "${BLUE}================================================================${NC}"
        echo ""
        echo "Usage: ./run.sh [1 | 2 | 3 | 4]"
        echo ""
        echo -e "  ${YELLOW}1${NC} : ${CYAN}Simulation till GTKWave waveform${NC}"
        echo "      -> ./run.sh 1  (or: bash 1_run_simulation_gtkwave.sh)"
        echo ""
        echo -e "  ${YELLOW}2${NC} : ${CYAN}Synthesis & Separated PPA Analysis${NC}"
        echo "      -> ./run.sh 2  (or: bash 2_run_synthesis_ppa.sh)"
        echo ""
        echo -e "  ${YELLOW}3${NC} : ${CYAN}OpenROAD Physical Layout GUI${NC}"
        echo "      -> ./run.sh 3  (or: bash 3_view_openroad_gui.sh)"
        echo ""
        echo -e "  ${YELLOW}4${NC} : ${CYAN}Complete Flow All at Once (Sim + Synth + PPA + PnR)${NC}"
        echo "      -> ./run.sh 4  (or: bash 4_run_complete_flow.sh)"
        echo ""
        echo -e "${YELLOW}Defaulting to Option [1]: Running simulation and launching GTKWave...${NC}\n"
        bash 1_run_simulation_gtkwave.sh
        ;;
esac
