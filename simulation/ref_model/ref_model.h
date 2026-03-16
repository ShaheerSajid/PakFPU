/*
 * ref_model.h — PakFPU reference model interface
 *
 * Thin C wrapper around Berkeley SoftFloat 3 that implements the same
 * operation/rounding-mode interface as fp_top, in both IEEE 754-2019 general
 * mode and RISC-V ISA mode.
 *
 * Build:
 *   See simulation/ref_model/Makefile — builds SoftFloat then this wrapper.
 *
 * RISC-V mode differences vs IEEE 754-2019 general mode:
 *   1. NaN boxing enforced on FP32 inputs  (upper 32 bits must be 0xFFFFFFFF)
 *   2. All NaN outputs replaced with the canonical quiet NaN
 *   3. FMIN/FMAX return the non-NaN operand when exactly one input is NaN
 *      (IEEE 754-2008 minNum/maxNum per the RISC-V ISA spec)
 */

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* -------------------------------------------------------------------------
 * Enumerations (must match fp_pkg.sv float_op_e / roundmode_e)
 * ------------------------------------------------------------------------- */

typedef enum {
    OP_FADD   = 0,
    OP_FMUL   = 1,
    OP_FDIV   = 2,
    OP_I2F    = 3,
    OP_F2I    = 4,
    OP_F2F    = 5,
    OP_FCMP   = 6,
    OP_FCLASS = 7,
    OP_FMIN   = 8,
    OP_FMAX   = 9,
    OP_FSGNJ  = 10,
    OP_FMADD  = 11,
} fp_op_t;

typedef enum {
    RM_RNE = 0,
    RM_RTZ = 1,
    RM_RDN = 2,
    RM_RUP = 3,
    RM_RMM = 4,
} round_mode_t;

typedef enum {
    FMT_FP32 = 0,
    FMT_FP64 = 2,
} fp_fmt_t;

typedef enum {
    INT_FMT_32 = 0,
    INT_FMT_64 = 1,
} int_fmt_t;

/* IEEE 754 exception flags — matches fp_top status_t bit layout {NV,DZ,OF,UF,NX} */
#define FLAG_NV  0x10u
#define FLAG_DZ  0x08u
#define FLAG_OF  0x04u
#define FLAG_UF  0x02u
#define FLAG_NX  0x01u

/* -------------------------------------------------------------------------
 * Result structure
 * ------------------------------------------------------------------------- */

typedef struct {
    uint64_t result; /* lower FP_WIDTH bits contain the FP result (or integer) */
    uint8_t  flags;  /* IEEE 754 exception flags                                */
} ref_result_t;

/* -------------------------------------------------------------------------
 * Main entry point
 * ------------------------------------------------------------------------- */

/**
 * ref_compute() — compute the reference result for one FP operation.
 *
 * @param op          Operation (fp_op_t)
 * @param op_modify   Sub-mode bits [1:0] (sub/sqrt/signed/sgnj variant)
 * @param fmt         Floating-point format (FMT_FP32 or FMT_FP64)
 * @param int_fmt     Integer format for I2F/F2I (INT_FMT_32 or INT_FMT_64)
 * @param rm          Rounding mode
 * @param a, b, c     64-bit operand slots (lower FP_WIDTH bits used for FP ops)
 * @param riscv_mode  1 = RISC-V semantics, 0 = IEEE 754-2019 general
 */
ref_result_t ref_compute(fp_op_t      op,
                         uint8_t      op_modify,
                         fp_fmt_t     fmt,
                         int_fmt_t    int_fmt,
                         round_mode_t rm,
                         uint64_t     a,
                         uint64_t     b,
                         uint64_t     c,
                         int          riscv_mode);

/* -------------------------------------------------------------------------
 * Utility
 * ------------------------------------------------------------------------- */

/** Returns 1 if the FP32 bit pattern is any NaN. */
static inline int is_nan_f32(uint32_t b)
{ return (b & 0x7F800000u) == 0x7F800000u && (b & 0x7FFFFFu) != 0; }

/** Returns 1 if the FP64 bit pattern is any NaN. */
static inline int is_nan_f64(uint64_t b)
{ return (b & 0x7FF0000000000000ULL) == 0x7FF0000000000000ULL
      && (b & 0x000FFFFFFFFFFFFFULL) != 0; }

/** Canonical quiet NaN bit patterns (RISC-V ISA spec). */
#define CANON_QNAN_F32  0x7FC00000u
#define CANON_QNAN_F64  0x7FF8000000000000ULL

#ifdef __cplusplus
}
#endif
