#!/bin/bash
# ==============================================================================
# Script 3: OpenROAD 45nm Chip Layout GUI Viewer
# Launches the interactive OpenROAD GUI to inspect physical floorplan,
# standard cell placement, power distribution grid, and routed metal tracks.
# Modeled identically after the companion LFSR-NFSR view_45nm_layout.sh.
#
# Usage:
#   ./3_view_openroad_gui.sh         : Opens Reconfigurable Dual-Mode MAC layout
#   ./3_view_openroad_gui.sh base    : Opens Base MAC layout
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

IMAGE_NAME="efabless/openlane:2023.09.07"

if [ "$1" = "base" ]; then
    DEF_FILE="results/mac_base_top_routed.def"
    GUI_TCL="scripts/load_base_gui.tcl"
    DESIGN="mac_base_top"
else
    DEF_FILE="results/mac_reconfigurable_top_routed.def"
    GUI_TCL="scripts/load_reconf_gui.tcl"
    DESIGN="mac_reconfigurable_top"
fi

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  [Step 3] Launching OpenROAD Physical Layout GUI (NanGate 45nm) ${NC}"
echo -e "${BLUE}================================================================${NC}"

# Check if routed DEF exists; if not, generate it first
if [ ! -f "$DEF_FILE" ]; then
    echo -e "${YELLOW}DEF layout not found: $DEF_FILE${NC}"
    echo -e "${YELLOW}Running OpenROAD Place & Route first to generate 45nm layout...${NC}"
    if [ "$1" = "base" ]; then
        docker run --rm -v "$PWD":/work -w /work "$IMAGE_NAME" openroad scripts/openroad_pnr_base.tcl
    else
        docker run --rm -v "$PWD":/work -w /work "$IMAGE_NAME" openroad scripts/openroad_pnr_reconf.tcl
    fi
fi

echo -e "${CYAN}Loading 45nm Chip Layout: $DEF_FILE${NC}"

# Allow local X11 display connection from Docker container
xhost +local:root >/dev/null 2>&1 || xhost + >/dev/null 2>&1 || true

# Set DISPLAY fallback for WSL/Windows X-servers
if [ -z "$DISPLAY" ]; then
    export DISPLAY=":0"
fi

# Launch OpenROAD GUI inside Docker with the 45nm layout
docker run --rm -it \
    --net=host \
    -e DISPLAY="$DISPLAY" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$SCRIPT_DIR":/work \
    -w /work \
    "$IMAGE_NAME" \
    openroad -gui "$GUI_TCL"

echo -e "${GREEN}✓ OpenROAD GUI session finished.${NC}"
