# PakFPU timing constraints for DE1-SoC (Cyclone V)
# Target: 50 MHz on CLOCK_50. Tighten the clock period to measure
# maximum achievable frequency (try 100 MHz, 150 MHz, etc.).

create_clock -name {CLOCK_50} -period 20.000 [get_ports {CLOCK_50}]

derive_pll_clocks
derive_clock_uncertainty

# Division and square root are multi-cycle operations (50+ cycles for FP32).
# Each pipeline register stage is still a single-cycle path, so no
# multicycle path constraint is needed for the STA.
#
# If you add retiming or restructure the div/sqrt FSM as a long
# combinational path, add set_multicycle_path constraints here.
