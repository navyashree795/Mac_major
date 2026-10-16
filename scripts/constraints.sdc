# =============================================================================
# SDC Timing Constraints: 16-bit Pipelined MAC Unit (Nangate 45nm)
# Target Clock Frequency: ~500 MHz (Clock Period = 2.0 ns)
# =============================================================================

create_clock -name clk -period 2.0 [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]

# Clean input/output port constraints compatible with OpenROAD
set_input_delay  0.2 -clock clk [get_ports {rst* clk_en* mode* acc_en* valid_in* signed_mode* a* b* acc_in*}]
set_output_delay 0.2 -clock clk [get_ports {valid_out* result* result_low* result_high* overflow*}]

