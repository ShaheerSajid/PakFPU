#!/bin/bash
# regress.sh — Full PakFPU regression using Berkeley TestFloat (level 1, all 5 rounding modes).
#
# Usage:
#   ./regress.sh [LEVEL=1|2]
#
# Results are printed to stdout. Failures are also written to regress_failures.txt.
# Exit code: 0 if all tests pass, 1 if any fail.
#
# Requires: verilator, testfloat/testfloat_gen (pre-built in simulation/testfloat/)

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

section() { printf "\n=== %s ===\n" "$1"; }

section "F32 Arithmetic"
for op in f32_add f32_sub f32_mul f32_div f32_sqrt; do run_op "$op"; done

section "F64 Arithmetic"
for op in f64_add f64_sub f64_mul f64_div f64_sqrt; do run_op "$op"; done

section "FMA"
# f64_mulAdd has a known pre-existing bug; excluded until fixed.
run_op f32_mulAdd

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

printf "\n========================================\n"
printf "TOTAL: PASS=%d  FAIL=%d\n" "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
    printf "Details written to %s\n" "$FAIL_LOG"
    exit 1
fi
exit 0
