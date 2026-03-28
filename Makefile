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

.PHONY: sim sim-all sim-regress formal \
        synth synth-map synth-fit synth-asm synth-sta synth-clean synth-archive \
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

# Formal verification (SymbiYosys BMC — requires sv2v and sby)
formal:
	$(MAKE) -C $(SIM)/formal -f Makefile.formal

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

synth-archive:
	$(MAKE) -C $(SYNTH) archive-reports $(MAKEOVERRIDES)

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
	@echo "  ROUND_MODE: 0=RNE 1=RTZ 2=RDN 3=RUP 4=RMM"
	@echo "  LEVEL:      1=standard  2=exhaustive"
	@echo "  TRACE=1     enable waveform dump (*.vcd)"
	@echo ""
	@echo "  For all simulation options:"
	@echo "  make -C simulation help"
	@echo ""
	@echo "Formal verification (requires sv2v + SymbiYosys/bitwuzla):"
	@echo "  make formal         BMC depth 32, FP32 + FP64, RISC-V mode"
	@echo ""
	@echo "Synthesis (Quartus, DE1-SoC Cyclone V):"
	@echo "  make synth          Full compile flow (map+fit+asm+sta)"
	@echo "  make synth-map      Analysis and synthesis only"
	@echo "  make synth-fit      Place and route only"
	@echo "  make synth-sta      Timing analysis only"
	@echo "  make synth-clean    Remove Quartus output files"
	@echo "  make synth-archive  Copy key .rpt files to reports/ for git tracking"
	@echo ""
	@echo "  QUARTUS_SH=<path>  Override Quartus shell path (default: quartus_sh)"
	@echo "  Results: synth/quartus/de1soc/output_files/"
	@echo ""
	@echo "General:"
	@echo "  make clean          Clean all generated files"
