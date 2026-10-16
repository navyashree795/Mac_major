#!/bin/bash
# ==============================================================================
# Script 1: RTL Functional Simulation & GTKWave Waveform Viewer
# Compiles both Base and Reconfigurable MAC units with Icarus Verilog and
# launches the waveform viewer.
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
echo -e "${BLUE}  [Step 1] RTL Simulation & GTKWave Waveform Verification       ${NC}"
echo -e "${BLUE}================================================================${NC}"

# --- Part 1: Base MAC Unit Simulation ---
echo -e "\n${YELLOW}[1/3] Compiling and running Base MAC (Tung & Huang 2020)...${NC}"
iverilog -g2005-sv -I rtl/core -o sim_base.vvp \
    rtl/core/full_adder.v \
    rtl/core/half_adder.v \
    rtl/core/compressor_4_2.v \
    rtl/core/carry_counter_overflow.v \
    rtl/core/han_carlson_adder.v \
    rtl/top/mac_base_top.v \
    tb/tb_mac_base.v
vvp sim_base.vvp
echo -e "${GREEN}✓ Base MAC Simulation Passed! (VCD -> mac_base_tb.vcd)${NC}"

# --- Part 2: Upgraded Reconfigurable Dual-Mode MAC Simulation ---
echo -e "\n${YELLOW}[2/3] Compiling and running Reconfigurable Dual-Mode MAC...${NC}"
iverilog -g2005-sv -I rtl/core -o sim_reconf.vvp \
    rtl/core/full_adder.v \
    rtl/core/half_adder.v \
    rtl/core/compressor_4_2.v \
    rtl/core/booth_radix4_encoder.v \
    rtl/core/booth_radix4_selector.v \
    rtl/core/carry_counter_overflow.v \
    rtl/core/han_carlson_adder.v \
    rtl/top/mac_reconfigurable_top.v \
    tb/tb_mac_reconfigurable.v
vvp sim_reconf.vvp
echo -e "${GREEN}✓ Reconfigurable MAC Simulation Passed! (VCD -> mac_reconfigurable_tb.vcd)${NC}"

# --- Part 3: Launch GTKWave GUI ---
echo -e "\n${CYAN}[3/3] Opening GTKWave GUI Window...${NC}"

open_gtkwave() {
    local vcd="$1"
    local gtkw="$2"
    
    if command -v gtkwave.exe &> /dev/null; then
        gtkwave.exe "$vcd" "$gtkw"
    elif command -v gtkwave &> /dev/null; then
        gtkwave "$vcd" "$gtkw"
    elif [ -f "/mnt/c/Users/WIN10/Desktop/gtkwave64/bin/gtkwave.exe" ]; then
        /mnt/c/Users/WIN10/Desktop/gtkwave64/bin/gtkwave.exe "$vcd" "$gtkw"
    elif [ -f "/mnt/c/iverilog/gtkwave/bin/gtkwave.exe" ]; then
        /mnt/c/iverilog/gtkwave/bin/gtkwave.exe "$vcd" "$gtkw"
    else
        echo "Error: gtkwave executable not found!"
        exit 1
    fi
}

if [ "$1" = "base" ]; then
    echo "Displaying Base MAC waveforms (mac_base_tb.vcd)..."
    open_gtkwave "mac_base_tb.vcd" "mac_base_tb.gtkw"
else
    echo "Displaying Reconfigurable Dual-Mode MAC waveforms (mac_reconfigurable_tb.vcd)..."
    open_gtkwave "mac_reconfigurable_tb.vcd" "mac_reconfigurable_tb.gtkw"
fi

echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}  Step 1 Complete! GTKWave session closed.                      ${NC}"
echo -e "${GREEN}================================================================${NC}"

