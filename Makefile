# PakFPU top-level Makefile
# Delegates to sub-makefiles for simulation and synthesis.
#
# Simulation variables (passed through to simulation/Makefile):
#   TEST, ROUND_MODE, LEVEL, TRACE, VERILATOR_OPT
#
# Synthesis variables (passed through to synth/quartus/de1soc/Makefile):
#   QUARTUS_SH

SIM   := simulation
SYNTH := synth/quartus/de1soc

.PHONY: sim sim-all sim-regress \
        synth synth-map synth-fit synth-asm synth-sta synth-clean \
        clean help

# ----------------------------------------------------------------
# Simulation
# ----------------------------------------------------------------

# Single run: make sim TEST=f32_add ROUND_MODE=0 LEVEL=1
sim:
	$(MAKE) -C $(SIM) verilator $(MAKEOVERRIDES)

# All rounding modes for one TEST: make sim-all TEST=f32_sqrt
sim-all:
	$(MAKE) -C $(SIM) verilator_all_rnd $(MAKEOVERRIDES)

# Full regression (all ops, all rounding modes)
sim-regress:
	cd $(SIM) && ./regress.sh $(LEVEL)

# ----------------------------------------------------------------
# Synthesis — Quartus / DE1-SoC
# ----------------------------------------------------------------

synth:
	$(MAKE) -C $(SYNTH) compile $(MAKEOVERRIDES)

synth-map:
	$(MAKE) -C $(SYNTH) map $(MAKEOVERRIDES)

synth-fit:
	$(MAKE) -C $(SYNTH) fit $(MAKEOVERRIDES)

synth-asm:
	$(MAKE) -C $(SYNTH) asm $(MAKEOVERRIDES)

synth-sta:
	$(MAKE) -C $(SYNTH) sta $(MAKEOVERRIDES)

synth-clean:
	$(MAKE) -C $(SYNTH) clean

# ----------------------------------------------------------------
# Misc
# ----------------------------------------------------------------

clean: synth-clean
	$(MAKE) -C $(SIM) clean

help:
	@echo "PakFPU — top-level Makefile"
	@echo ""
	@echo "Simulation (Verilator + Berkeley TestFloat):"
	@echo "  make sim            TEST=f32_add [ROUND_MODE=0] [LEVEL=1]"
	@echo "  make sim-all        TEST=f32_sqrt                 (all 5 rounding modes)"
	@echo "  make sim-regress    [LEVEL=1|2]                   (175-run full sweep)"
	@echo ""
	@echo "  For all simulation options:"
	@echo "  make -C simulation help"
	@echo ""
	@echo "Synthesis (Quartus, DE1-SoC Cyclone V):"
	@echo "  make synth          Full compile flow (map+fit+asm+sta)"
	@echo "  make synth-map      Analysis and synthesis only"
	@echo "  make synth-fit      Place and route only"
	@echo "  make synth-sta      Timing analysis only"
	@echo "  make synth-clean    Remove Quartus output files"
	@echo ""
	@echo "  QUARTUS_SH=<path>  Override Quartus shell path (default: quartus_sh)"
	@echo ""
	@echo "  Results: synth/quartus/de1soc/output_files/"
	@echo "    *.fit.rpt  — area (ALMs, FFs, DSPs)"
	@echo "    *.sta.rpt  — timing (Fmax)"
	@echo ""
	@echo "General:"
	@echo "  make clean          Clean all generated files"
