#!/bin/bash
# regress.sh — Full PakFPU regression using Berkeley TestFloat + directed tests.
#
# Usage:
#   ./regress.sh [LEVEL=1|2]
#
# Sections:
#   1. TestFloat-based: all arithmetic/compare/convert ops (176 runs, 5 rounding modes each)
#   2. Directed special-value: min/max/classify (no testfloat_gen vectors for these ops)
#
# Results are printed to stdout. Failures are also written to regress_failures.txt.
# Exit code: 0 if all tests pass, 1 if any fail.
#
# Requires: verilator, python3, testfloat/testfloat_gen (pre-built in simulation/testfloat/)

set -euo pipefail
SIM="$(cd "$(dirname "$0")" && pwd)"
LEVEL="${1:-1}"
PASS=0; FAIL=0
FAIL_LOG="$SIM/regress_failures.txt"
> "$FAIL_LOG"

rm_name() { case $1 in 0) echo RNE;; 1) echo RTZ;; 2) echo RDN;; 3) echo RUP;; 4) echo RMM;; esac; }

run_op() {
    local op=$1
    # Generate test vectors once for all rounding modes.
    make -s -C "$SIM" gen_test TEST="$op" LEVEL="$LEVEL" 2>/dev/null
    for rm in 0 1 2 3 4; do
        local res
        res=$(make -s -C "$SIM" verilator_sim TEST="$op" ROUND_MODE=$rm LEVEL="$LEVEL" 2>&1)
        if echo "$res" | grep -q "Total Errors = 0"; then
            printf "  %-28s RM=%-3s  PASS\n" "$op" "$(rm_name $rm)"
            PASS=$((PASS+1))
        else
            local errs
            errs=$(echo "$res" | grep -oP 'Total Errors = \d+/\d+' | head -1)
            printf "  %-28s RM=%-3s  FAIL  %s\n" "$op" "$(rm_name $rm)" "$errs"
            {
                echo "--- $op  RM=$(rm_name $rm) ---"
                echo "$res" | grep -E "MISMATCH|Total Errors" | head -5
            } >> "$FAIL_LOG"
            FAIL=$((FAIL+1))
        fi
    done
}

# Run a directed special-value test (no testfloat_gen required).
# Generates all combinations of special values via gen_directed.py and pipes
# into the Verilator binary compiled for the given TEST operation.
# Args: test  gen_op  fmt  num_inputs  result_bits
run_directed() {
    local test=$1 gen_op=$2 fmt=$3 num_inputs=$4 result_bits=$5
    # Compile the binary for the right OP_SEL (silently).
    make -s -C "$SIM" verilator_compile TEST="$test" 2>/dev/null
    local res
    # --no-flags: skip exception flag comparison (directed ref model is approximate).
    # rm=0 (RNE) is passed but min/max/classify are rounding-mode independent.
    res=$(python3 "$SIM/directed/gen_directed.py" \
          --fmt "$fmt" --op "$gen_op" --rm 0 --no-flags 2>/dev/null | \
          "$SIM/obj_dir/Vtb" /dev/stdin 0 "$num_inputs" "$result_bits" 0 2>&1)
    if echo "$res" | grep -q "Total Errors = 0"; then
        printf "  %-28s DIRECTED  PASS\n" "$test"
        PASS=$((PASS+1))
    else
        local errs
        errs=$(echo "$res" | grep -oP 'Total Errors = \d+/\d+' | head -1)
        printf "  %-28s DIRECTED  FAIL  %s\n" "$test" "$errs"
        {
            echo "--- $test directed ---"
            echo "$res" | grep -E "Expected|Total Errors" | head -5
        } >> "$FAIL_LOG"
        FAIL=$((FAIL+1))
    fi
}

section() { printf "\n=== %s ===\n" "$1"; }

section "F32 Arithmetic"
for op in f32_add f32_sub f32_mul f32_div f32_sqrt; do run_op "$op"; done

section "F64 Arithmetic"
for op in f64_add f64_sub f64_mul f64_div f64_sqrt; do run_op "$op"; done

section "FMA"
for op in f32_mulAdd f64_mulAdd; do run_op "$op"; done

section "Compare (F32 + F64)"
for op in f32_le f32_eq f32_lt f64_le f64_eq f64_lt; do run_op "$op"; done

section "F2F Conversion"
for op in f32_to_f64 f64_to_f32; do run_op "$op"; done

section "Integer-to-Float"
for op in i32_to_f32 ui32_to_f32 i64_to_f32 ui64_to_f32 \
          i32_to_f64 ui32_to_f64 i64_to_f64 ui64_to_f64; do
    run_op "$op"
done

section "Float-to-Integer"
for op in f32_to_i32 f32_to_ui32 f32_to_i64 f32_to_ui64 \
          f64_to_i32 f64_to_ui32 f64_to_i64 f64_to_ui64; do
    run_op "$op"
done

# ---------------------------------------------------------------------------
# Directed special-value tests (no testfloat_gen vectors for these ops)
# Tests all combinations of ±0, ±∞, sNaN, qNaN, ±subnormal, ±normal.
# Exception flags are NOT checked (directed ref model is approximate).
# ---------------------------------------------------------------------------
section "Min / Max (directed special values)"
run_directed f32_min   min      fp32  2  32
run_directed f32_max   max      fp32  2  32
run_directed f64_min   min      fp64  2  64
run_directed f64_max   max      fp64  2  64

section "Classify (directed special values)"
run_directed f32_classify  classify  fp32  1  10
run_directed f64_classify  classify  fp64  1  10

printf "\n========================================\n"
printf "TOTAL: PASS=%d  FAIL=%d\n" "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
    printf "Details written to %s\n" "$FAIL_LOG"
    exit 1
fi
exit 0
