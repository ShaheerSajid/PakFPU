PROJECT     := de1soc
QUARTUS_SH  ?= quartus_sh

.PHONY: all compile fit asm sta clean help

all: compile

# Full compile flow (map → fit → asm → sta)
compile:
	$(QUARTUS_SH) --flow compile $(PROJECT)

# Individual stages (useful for iterating on timing)
map:
	quartus_map $(PROJECT)

fit:
	quartus_fit $(PROJECT)

asm:
	quartus_asm $(PROJECT)

sta:
	quartus_sta $(PROJECT)

clean:
	rm -rf output_files db incremental_db
	rm -f *.qws *.rpt *.pin *.sof *.pof

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all / compile   Full Quartus compile flow (map+fit+asm+sta)"
	@echo "  map             Analysis and synthesis only"
	@echo "  fit             Placement and routing only"
	@echo "  asm             Assembler (generates .sof)"
	@echo "  sta             Timing analysis only"
	@echo "  clean           Remove Quartus output files"
	@echo ""
	@echo "Variables:"
	@echo "  QUARTUS_SH=quartus_sh   Path to Quartus shell (override if not in PATH)"
	@echo ""
	@echo "Results land in output_files/$(PROJECT).sta.rpt (timing)"
	@echo "and output_files/$(PROJECT).fit.rpt (area / ALMs / FFs)."
