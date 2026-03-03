TEST ?= f32_add
LEVEL ?= 1
TRACE ?= 0
VERILATOR_OPT ?= 2

# Auto-decode runtime/op config from Berkeley TestFloat TEST keyword.
# Enum encodings:
# FP_FORMAT: FP32=0, FP48=1, FP64=2
# INT_FORMAT: INT32=0, INT64=1
# OP_SEL: FADD=0, FMUL=1, FDIV=2, I2F=3, F2I=4, F2F=5, FCMP=6, FCLASS=7, FMIN=8, FMAX=9, FSGNJ=10, FMADD=11
AUTO_MATCH := 0
AUTO_FP_FORMAT := 0
AUTO_INT_FORMAT := 0
AUTO_OP_SEL := 2
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 2
AUTO_RESULT_BITS := 32
AUTO_CHECK_FLAGS := 1

# Base format defaults from TEST prefix.
ifneq ($(filter f32_%,$(TEST)),)
AUTO_FP_FORMAT := 0
AUTO_RESULT_BITS := 32
endif
ifneq ($(filter f64_%,$(TEST)),)
AUTO_FP_FORMAT := 2
AUTO_RESULT_BITS := 64
endif

# Arithmetic
ifneq ($(filter f32_add f64_add,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 0
AUTO_OP_MODIFY := 0
endif
ifneq ($(filter f32_sub f64_sub,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 0
AUTO_OP_MODIFY := 1
endif
ifneq ($(filter f32_mul f64_mul,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 1
AUTO_OP_MODIFY := 0
endif
ifneq ($(filter f32_div f64_div,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 2
AUTO_OP_MODIFY := 0
endif
ifneq ($(filter f32_sqrt f64_sqrt,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 2
AUTO_OP_MODIFY := 1
AUTO_NUM_INPUTS := 1
endif

# FMA family
ifneq ($(filter f32_mulAdd f64_mulAdd,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 11
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 3
endif
ifneq ($(filter f32_mulSub f64_mulSub,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 11
AUTO_OP_MODIFY := 1
AUTO_NUM_INPUTS := 3
endif
ifneq ($(filter f32_negMulAdd f64_negMulAdd,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 11
AUTO_OP_MODIFY := 2
AUTO_NUM_INPUTS := 3
endif
ifneq ($(filter f32_negMulSub f64_negMulSub,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 11
AUTO_OP_MODIFY := 3
AUTO_NUM_INPUTS := 3
endif

# Compare
ifneq ($(filter f32_le f64_le,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 6
AUTO_OP_MODIFY := 0
AUTO_RESULT_BITS := 1
endif
ifneq ($(filter f32_eq f64_eq,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 6
AUTO_OP_MODIFY := 1
AUTO_RESULT_BITS := 1
endif
ifneq ($(filter f32_lt f64_lt,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 6
AUTO_OP_MODIFY := 2
AUTO_RESULT_BITS := 1
endif
ifneq ($(filter f32_eq_signaling f64_eq_signaling f32_le_quiet f64_le_quiet f32_lt_quiet f64_lt_quiet,$(TEST)),)
$(error TEST '$(TEST)' requires compare mode variants not encoded in current fp_top op_modify_i)
endif

# Min/Max and classify
ifneq ($(filter f32_min f64_min,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 8
AUTO_OP_MODIFY := 0
endif
ifneq ($(filter f32_max f64_max,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 9
AUTO_OP_MODIFY := 0
endif
ifneq ($(filter f32_classify f64_classify,$(TEST)),)
AUTO_MATCH := 1
AUTO_OP_SEL := 7
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 10
endif

# Unsupported (for current RTL top-level wrapper)
ifneq ($(filter f32_rem f64_rem,$(TEST)),)
$(error TEST '$(TEST)' maps to remainder operation, not implemented in fp_top)
endif
ifneq ($(filter f32_roundToInt f64_roundToInt,$(TEST)),)
$(error TEST '$(TEST)' maps to roundToInt operation, not implemented in fp_top)
endif

# FP<->FP
ifneq ($(filter f32_to_f64,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 2
AUTO_OP_SEL := 5
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 64
endif
ifneq ($(filter f64_to_f32,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 0
AUTO_OP_SEL := 5
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 32
endif

# i2f
ifneq ($(filter i32_to_f32,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 0
AUTO_INT_FORMAT := 0
AUTO_OP_SEL := 3
AUTO_OP_MODIFY := 1
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 32
endif
ifneq ($(filter ui32_to_f32,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 0
AUTO_INT_FORMAT := 0
AUTO_OP_SEL := 3
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 32
endif
ifneq ($(filter i32_to_f64,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 2
AUTO_INT_FORMAT := 0
AUTO_OP_SEL := 3
AUTO_OP_MODIFY := 1
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 64
endif
ifneq ($(filter ui32_to_f64,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 2
AUTO_INT_FORMAT := 0
AUTO_OP_SEL := 3
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 64
endif
ifneq ($(filter i64_to_f64,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 2
AUTO_INT_FORMAT := 1
AUTO_OP_SEL := 3
AUTO_OP_MODIFY := 1
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 64
endif
ifneq ($(filter ui64_to_f64,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 2
AUTO_INT_FORMAT := 1
AUTO_OP_SEL := 3
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 64
endif
ifneq ($(filter i64_to_f32,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 0
AUTO_INT_FORMAT := 1
AUTO_OP_SEL := 3
AUTO_OP_MODIFY := 1
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 32
endif
ifneq ($(filter ui64_to_f32,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 0
AUTO_INT_FORMAT := 1
AUTO_OP_SEL := 3
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 32
endif

# f2i
ifneq ($(filter f32_to_i32,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 0
AUTO_INT_FORMAT := 0
AUTO_OP_SEL := 4
AUTO_OP_MODIFY := 1
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 32
endif
ifneq ($(filter f32_to_ui32,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 0
AUTO_INT_FORMAT := 0
AUTO_OP_SEL := 4
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 32
endif
ifneq ($(filter f64_to_i32,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 2
AUTO_INT_FORMAT := 0
AUTO_OP_SEL := 4
AUTO_OP_MODIFY := 1
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 32
endif
ifneq ($(filter f64_to_ui32,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 2
AUTO_INT_FORMAT := 0
AUTO_OP_SEL := 4
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 32
endif
ifneq ($(filter f64_to_i64,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 2
AUTO_INT_FORMAT := 1
AUTO_OP_SEL := 4
AUTO_OP_MODIFY := 1
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 64
endif
ifneq ($(filter f64_to_ui64,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 2
AUTO_INT_FORMAT := 1
AUTO_OP_SEL := 4
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 64
endif
ifneq ($(filter f32_to_i64,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 0
AUTO_INT_FORMAT := 1
AUTO_OP_SEL := 4
AUTO_OP_MODIFY := 1
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 64
endif
ifneq ($(filter f32_to_ui64,$(TEST)),)
AUTO_MATCH := 1
AUTO_FP_FORMAT := 0
AUTO_INT_FORMAT := 1
AUTO_OP_SEL := 4
AUTO_OP_MODIFY := 0
AUTO_NUM_INPUTS := 1
AUTO_RESULT_BITS := 64
endif

ifneq ($(strip $(TEST)),)
ifeq ($(AUTO_MATCH),0)
$(error Unsupported TEST keyword '$(TEST)' for current Makefile mapping)
endif
endif

FP_FORMAT ?= $(AUTO_FP_FORMAT)
INT_FORMAT ?= $(AUTO_INT_FORMAT)
OP_SEL ?= $(AUTO_OP_SEL)
OP_MODIFY ?= $(AUTO_OP_MODIFY)
NUM_INPUTS ?= $(AUTO_NUM_INPUTS)
RESULT_BITS ?= $(AUTO_RESULT_BITS)
CHECK_FLAGS ?= $(AUTO_CHECK_FLAGS)

# main.cpp runtime controls
# Use ROUND_MODE instead of RM to avoid collision with GNU Make's built-in RM=rm -f.
ROUND_MODE ?= 1
# Backward-compatible override if user passes RM on command line.
ifeq ($(origin RM),command line)
ROUND_MODE := $(RM)
endif
# Restore GNU Make remove command so recursive make (obj_dir/Vtb.mk) is not broken.
override RM := rm -f

ifeq ($(ROUND_MODE),0)
RM_TAG := rne
else ifeq ($(ROUND_MODE),1)
RM_TAG := rtz
else ifeq ($(ROUND_MODE),2)
RM_TAG := rdn
else ifeq ($(ROUND_MODE),3)
RM_TAG := rup
else ifeq ($(ROUND_MODE),4)
RM_TAG := rmm
else
$(error Unsupported ROUND_MODE='$(ROUND_MODE)'. Use 0:RNE 1:RTZ 2:RDN 3:RUP 4:RMM)
endif
TEST_FILE ?= testbench/test_$(RM_TAG).txt

ifeq ($(TRACE),1)
TRACE_ARGS := --trace
else ifeq ($(TRACE),0)
TRACE_ARGS :=
else
$(error Unsupported TRACE='$(TRACE)'. Use 0 or 1)
endif

gen_test:
	@echo "Generating test vectors for $(TEST) at level $(LEVEL)"
	@echo "  RDN..."; ./testfloat/testfloat_gen ${TEST} -tininessafter -rmin     -seed 1000 -level $(LEVEL) > testbench/test_rdn.txt
	@echo "  RUP..."; ./testfloat/testfloat_gen ${TEST} -tininessafter -rmax     -seed 1000 -level $(LEVEL) > testbench/test_rup.txt
	@echo "  RTZ..."; ./testfloat/testfloat_gen ${TEST} -tininessafter -rminMag  -seed 1000 -level $(LEVEL) > testbench/test_rtz.txt
	@echo "  RNE..."; ./testfloat/testfloat_gen ${TEST} -tininessafter -rnear_even    -seed 1000 -level $(LEVEL) > testbench/test_rne.txt
	@echo "  RMM..."; ./testfloat/testfloat_gen ${TEST} -tininessafter -rnear_maxMag  -seed 1000 -level $(LEVEL) > testbench/test_rmm.txt

questa_sim:
	if [ -d "work" ]; then  vdel -lib work -all; fi
	vlib work
	vlog -sv -work work -f src.args
	vlog -sv -work work +incdir+../src testbench/tb.sv
	vsim -t 1ps -L work -voptargs="+acc" tb -do "do wave.do; run -all; exit"
	
verilator_sim:
	echo "Compiling Testbench"
	verilator \
	-Wno-WIDTH \
	-Wno-PINMISSING \
	-O$(VERILATOR_OPT) \
	$(TRACE_ARGS) \
	--timescale-override 1ns/10ps \
	-GFP_FORMAT_I=$(FP_FORMAT) \
	-GINT_FORMAT_I=$(INT_FORMAT) \
	-GOP_SEL_I=$(OP_SEL) \
	-GOP_MODIFY_I=$(OP_MODIFY) \
	-sv --top-module tb \
	--cc \
	+incdir+../src \
	-f src.args \
	testbench/tb.sv \
	--exe testbench/main.cpp
	make -s -j -C obj_dir/ -f Vtb.mk Vtb OBJCACHE=
	echo "Running Testbench"
	echo "Config: OP_SEL=$(OP_SEL) OP_MODIFY=$(OP_MODIFY) FP_FORMAT=$(FP_FORMAT) INT_FORMAT=$(INT_FORMAT) TRACE=$(TRACE)"
	echo "Input: TEST_FILE=$(TEST_FILE) ROUND_MODE=$(ROUND_MODE) NUM_INPUTS=$(NUM_INPUTS) RESULT_BITS=$(RESULT_BITS) CHECK_FLAGS=$(CHECK_FLAGS)"
	echo -n "${TEST} run: "
	echo "${TEST} run Errors" >> err.txt
	obj_dir/Vtb $(TEST_FILE) $(ROUND_MODE) $(NUM_INPUTS) $(RESULT_BITS) $(CHECK_FLAGS) 2>> err.txt
	
	
# Run verilator across all 5 rounding modes for the given TEST.
.PHONY: verilator_all_rnd
verilator_all_rnd: gen_test
	@for rm in 0 1 2 3 4; do \
	  $(MAKE) -s verilator_sim TEST=$(TEST) ROUND_MODE=$$rm LEVEL=$(LEVEL) TRACE=$(TRACE); \
	done

.PHONY: help
help:
	@echo "Usage: make <target> [VARIABLE=value ...]"
	@echo ""
	@echo "Targets:"
	@echo "  gen_test          Generate Berkeley TestFloat vectors for TEST"
	@echo "  verilator         gen_test + Verilator compile + run (single rounding mode)"
	@echo "  verilator_all_rnd gen_test + Verilator run across all 5 rounding modes"
	@echo "  questa            gen_test + QuestaSim compile + run"
	@echo "  clean             Remove generated files"
	@echo ""
	@echo "Key variables (defaults shown):"
	@echo "  TEST=f32_add      Berkeley TestFloat operation keyword"
	@echo "  ROUND_MODE=1      0:RNE  1:RTZ  2:RDN  3:RUP  4:RMM"
	@echo "  LEVEL=1           TestFloat generation level (1 or 2)"
	@echo "  TRACE=0           1 to enable waveform dump"
	@echo "  VERILATOR_OPT=2   Verilator optimisation level (0-3)"
	@echo ""
	@echo "Examples:"
	@echo "  make verilator TEST=f32_div ROUND_MODE=0 LEVEL=1"
	@echo "  make verilator TEST=f64_mul ROUND_MODE=0 LEVEL=2 TRACE=1"
	@echo "  make verilator_all_rnd TEST=f32_sqrt LEVEL=1"
	@echo ""
	@echo "Supported TEST keywords (auto-decoded):"
	@echo "  Arithmetic : f32_add f32_sub f32_mul f32_div f32_sqrt  (and f64_* variants)"
	@echo "  FMA        : f32_mulAdd f64_mulAdd"
	@echo "               (mulSub/negMulAdd/negMulSub have no testfloat_gen vectors;"
	@echo "                use TEST=f32_mulAdd with OP_MODIFY=1/2/3 for RTL-only runs)"
	@echo "  Compare    : f32_le f32_eq f32_lt"
	@echo "  Min/Max    : f32_min f32_max"
	@echo "  Classify   : f32_classify"
	@echo "  Conversion : f32_to_f64 f64_to_f32"
	@echo "               i32_to_f32 ui32_to_f32 i64_to_f32 ui64_to_f32"
	@echo "               i32_to_f64 ui32_to_f64 i64_to_f64 ui64_to_f64"
	@echo "               f32_to_i32 f32_to_ui32 f32_to_i64 f32_to_ui64"
	@echo "               f64_to_i32 f64_to_ui32 f64_to_i64 f64_to_ui64"

.PHONY: questa
questa: gen_test questa_sim

.PHONY: verilator
verilator: gen_test verilator_sim

.PHONY: clean
clean:
	rm -rf testbench/*.txt
	rm -rf work
	rm -rf transcript *.wlf
	rm -rf *.txt
	rm -rf obj_dir
	rm -rf *.vcd
	rm -rf gen_test
