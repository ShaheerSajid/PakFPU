/*
 * main_refmodel.cpp — Verilator testbench with inline reference model.
 *
 * Unlike main.cpp (which reads pre-generated Berkeley TestFloat vector files),
 * this harness generates expected results at runtime by calling the C++
 * reference model (ref_model.cpp → SoftFloat).  This enables:
 *
 *   1. Directed special-value tests (stdin or file, without expected values)
 *   2. RISC-V mode verification (NaN boxing, canonical NaN, minNum/maxNum)
 *   3. Co-simulation against any set of input vectors
 *
 * Input format (stdin or file):  one test per line, space-separated hex values
 *   FP32 binary:  AAAAAAAA BBBBBBBB
 *   FP64 binary:  AAAAAAAAAAAAAAAA BBBBBBBBBBBBBBBB
 *   FP32 unary:   AAAAAAAA
 *   FP32 3-input: AAAAAAAA BBBBBBBB CCCCCCCC
 *
 * Lines starting with '#' are comments and are skipped.
 *
 * Usage:
 *   obj_dir_ref/Vtb <rm> <fp_fmt> <int_fmt> <op> <op_modify>
 *                   <num_inputs> <result_bits> [--riscv] [--no-flags]
 *                   [file]
 *
 *   rm          : 0=RNE 1=RTZ 2=RDN 3=RUP 4=RMM
 *   fp_fmt      : 0=FP32 2=FP64
 *   int_fmt     : 0=INT32 1=INT64
 *   op          : operation enum value (see fp_pkg.sv float_op_e)
 *   op_modify   : sub-mode [1:0]
 *   num_inputs  : 1, 2, or 3
 *   result_bits : 32 or 64
 *   --riscv     : enable RISC-V semantics (NaN boxing, canonical NaN, etc.)
 *   --no-flags  : skip exception flag comparison
 *   file        : input file (default: stdin)
 */

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include "Vtb.h"
#include "verilated.h"
#if VM_TRACE
#include "verilated_vcd_c.h"
#endif

/* Reference model — built against SoftFloat */
#include "../ref_model/ref_model.h"

static vluint64_t sim_time = 0;

static void clock_cycle(Vtb *tb)
{
    tb->clk = 0; tb->eval(); sim_time++;
    tb->clk = 1; tb->eval(); sim_time++;
}

static uint64_t parse_hex(const char *s)
{
    return strtoull(s, nullptr, 16);
}

static void print_usage(const char *prog)
{
    fprintf(stderr,
        "Usage: %s <rm> <fp_fmt> <int_fmt> <op> <op_modify>"
        " <num_inputs> <result_bits> [--riscv] [--no-flags] [file]\n",
        prog);
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(VM_TRACE);

    if (argc < 8) { print_usage(argv[0]); return 1; }

    int         rm           = atoi(argv[1]);
    int         fp_fmt_i     = atoi(argv[2]);
    int         int_fmt_i    = atoi(argv[3]);
    int         op_i         = atoi(argv[4]);
    int         op_modify    = atoi(argv[5]);
    int         num_inputs   = atoi(argv[6]);
    int         result_bits  = atoi(argv[7]);
    int         riscv_mode   = 0;
    int         check_flags  = 1;
    const char *input_file   = nullptr;

    for (int i = 8; i < argc; i++) {
        if (strcmp(argv[i], "--riscv")    == 0) riscv_mode  = 1;
        else if (strcmp(argv[i], "--no-flags") == 0) check_flags = 0;
        else input_file = argv[i];
    }

    round_mode_t rm_ref   = (round_mode_t)rm;
    fp_fmt_t     fmt_ref  = (fp_fmt_t)fp_fmt_i;
    int_fmt_t    ifmt_ref = (int_fmt_t)int_fmt_i;
    fp_op_t      op_ref   = (fp_op_t)op_i;

    const uint64_t result_mask = (result_bits == 64) ? ~0ULL
                                                     : ((1ULL << result_bits) - 1ULL);

    Vtb *tb = new Vtb;
#if VM_TRACE
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    tb->trace(m_trace, 2);
    m_trace->open("waveform_ref.vcd");
#endif

    /* Reset */
    tb->rst = 0; tb->start = 0; tb->rnd = rm;
    clock_cycle(tb);
    tb->rst = 1;
    clock_cycle(tb);

    FILE *fp = input_file ? fopen(input_file, "r") : stdin;
    if (!fp) { perror(input_file); return 1; }

    char   *line = nullptr;
    size_t  len  = 0;
    ssize_t nread;
    uint32_t test_cnt = 0, err_cnt = 0;

    while ((nread = getline(&line, &len, fp)) != -1) {
        /* Strip trailing newline */
        while (nread > 0 && (line[nread-1] == '\n' || line[nread-1] == '\r'))
            line[--nread] = '\0';

        if (line[0] == '#' || line[0] == '\0') continue;

        /* Parse input operands */
        char *tok[4];
        int   ntok = 0;
        char *p = strtok(line, " \t");
        while (p && ntok < 4) { tok[ntok++] = p; p = strtok(nullptr, " \t"); }

        if (ntok < num_inputs) continue;

        uint64_t a = parse_hex(tok[0]);
        uint64_t b = (num_inputs >= 2) ? parse_hex(tok[1]) : 0;
        uint64_t c = (num_inputs >= 3) ? parse_hex(tok[2]) : 0;

        /* Compute reference result */
        ref_result_t ref = ref_compute(op_ref, (uint8_t)op_modify,
                                       fmt_ref, ifmt_ref,
                                       rm_ref, a, b, c, riscv_mode);

        /* Drive DUT */
        test_cnt++;
        tb->opA   = a;
        tb->opB   = b;
        tb->opC   = c;
        tb->rnd   = rm;
        tb->start = 1;
        clock_cycle(tb);
        tb->start = 0;

        /* Wait for valid */
        int timeout = 4096;
        while (!tb->valid && --timeout > 0) clock_cycle(tb);
        if (timeout == 0) {
            fprintf(stderr, "TIMEOUT: %016llx %016llx %016llx\n",
                    (unsigned long long)a, (unsigned long long)b,
                    (unsigned long long)c);
            err_cnt++;
            continue;
        }

        uint64_t actual_res  = tb->result;
        uint8_t  actual_flgs = tb->flags_o;

        int res_match  = ((ref.result & result_mask) == (actual_res & result_mask));
        int flg_match  = (!check_flags || ref.flags == actual_flgs);

        if (!res_match || !flg_match) {
            fprintf(stderr,
                "FAIL  A=%016llx B=%016llx C=%016llx"
                "  ExpRes=%016llx ActRes=%016llx"
                "  ExpFlg=%02x ActFlg=%02x%s%s\n",
                (unsigned long long)a,
                (unsigned long long)b,
                (unsigned long long)c,
                (unsigned long long)(ref.result & result_mask),
                (unsigned long long)(actual_res & result_mask),
                ref.flags, actual_flgs,
                res_match  ? "" : "  [RESULT MISMATCH]",
                flg_match  ? "" : "  [FLAG MISMATCH]");
            err_cnt++;
        }
    }

    fprintf(stdout, "Total Errors = %u/%u\t (%0.2f%%)\n",
            err_cnt, test_cnt,
            test_cnt ? err_cnt * 100.0 / test_cnt : 0.0);

    fclose(fp);
    free(line);
#if VM_TRACE
    m_trace->close();
    delete m_trace;
#endif
    delete tb;
    return (err_cnt > 0) ? 1 : 0;
}
