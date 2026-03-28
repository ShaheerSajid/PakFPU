# simulation/ref_model/Makefile
#
# Builds Berkeley SoftFloat 3 from source, then compiles ref_model.cpp into
# a static library (librefmodel.a) that the Verilator testbench links against.
#
# Prerequisites:
#   git submodule update --init --recursive
#   OR: make fetch-softfloat
#
# The SoftFloat source is expected at:
#   simulation/ref_model/softfloat/   (Berkeley-SoftFloat-3 repo)

SOFTFLOAT_DIR := softfloat
SOFTFLOAT_SRC := $(SOFTFLOAT_DIR)/source
SOFTFLOAT_BUILD := $(SOFTFLOAT_DIR)/build/Linux-x86_64-GCC
SOFTFLOAT_LIB := $(SOFTFLOAT_BUILD)/softfloat.a
SOFTFLOAT_INC := $(SOFTFLOAT_DIR)/source/include

REF_MODEL_LIB := librefmodel.a
REF_MODEL_OBJ := ref_model.o

CXX      ?= g++
CC       ?= gcc
CXXFLAGS := -O2 -std=c++11 -I$(SOFTFLOAT_INC) -DSOFTFLOAT_FAST_INT64

.PHONY: all clean fetch-softfloat

all: $(REF_MODEL_LIB)

# ---------------------------------------------------------------------------
# Fetch Berkeley SoftFloat 3 if not already present
# ---------------------------------------------------------------------------
fetch-softfloat:
	@if [ ! -f "$(SOFTFLOAT_SRC)/f32_add.c" ]; then \
	    echo "Cloning Berkeley SoftFloat 3..."; \
	    git clone --depth 1 https://github.com/ucb-bar/berkeley-softfloat-3 $(SOFTFLOAT_DIR); \
	else \
	    echo "SoftFloat already present."; \
	fi

# ---------------------------------------------------------------------------
# Build SoftFloat
# ---------------------------------------------------------------------------
$(SOFTFLOAT_LIB): fetch-softfloat
	$(MAKE) -C $(SOFTFLOAT_BUILD) CC=$(CC) \
	    SPECIALIZE_TYPE=RISCV \
	    SOFTFLOAT_OPTS="-DSOFTFLOAT_FAST_INT64 -DSOFTFLOAT_ROUND_ODD"

# ---------------------------------------------------------------------------
# Build ref_model
# ---------------------------------------------------------------------------
$(REF_MODEL_OBJ): ref_model.cpp ref_model.h $(SOFTFLOAT_LIB)
	$(CXX) $(CXXFLAGS) -c ref_model.cpp -o $@

$(REF_MODEL_LIB): $(REF_MODEL_OBJ) $(SOFTFLOAT_LIB)
	ar rcs $@ $^

clean:
	rm -f $(REF_MODEL_OBJ) $(REF_MODEL_LIB)
	$(MAKE) -C $(SOFTFLOAT_BUILD) clean 2>/dev/null || true
