PROJECT     := de1soc
QUARTUS_SH  ?= quartus_sh
REPORTS_DIR := reports

.PHONY: all compile fit asm sta archive-reports compile-and-archive clean help

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

# Copy key synthesis reports into reports/ for git tracking.
# Run after 'compile' (full flow) or 'map' (area-only check).
archive-reports:
	@mkdir -p $(REPORTS_DIR)
	@for rpt in map fit sta; do \
	    src=output_files/$(PROJECT).$$rpt.rpt; \
	    if [ -f "$$src" ]; then \
	        cp "$$src" $(REPORTS_DIR)/$$rpt.rpt; \
	        echo "Archived $$src → $(REPORTS_DIR)/$$rpt.rpt"; \
	    fi; \
	done

# Full compile followed by report archiving.
compile-and-archive: compile archive-reports

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
	@echo "  archive-reports         Copy key .rpt files to reports/ for git tracking"
	@echo "  compile-and-archive     Full compile + archive in one step"
	@echo ""
	@echo "Variables:"
	@echo "  QUARTUS_SH=quartus_sh   Path to Quartus shell (override if not in PATH)"
	@echo ""
	@echo "Results land in output_files/$(PROJECT).sta.rpt (timing)"
	@echo "and output_files/$(PROJECT).fit.rpt (area / ALMs / FFs)."
	@echo "Archived reports are tracked in $(REPORTS_DIR)/."
