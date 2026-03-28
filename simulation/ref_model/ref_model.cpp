/*
 * ref_model.cpp — PakFPU reference model implementation
 *
 * Wraps Berkeley SoftFloat 3 to provide the same operation/rounding-mode
 * interface as fp_top.  Implements both IEEE 754-2019 general mode and the
 * RISC-V ISA variant (NaN boxing, canonical NaN output, minNum/maxNum).
 */

#include "ref_model.h"

/* SoftFloat public header — wrap in extern "C" since softfloat.h has no guard */
extern "C" {
#include "softfloat.h"
}

#include <string.h>

/* -------------------------------------------------------------------------
 * SoftFloat rounding mode mapping
 * ------------------------------------------------------------------------- */

static void set_rm(round_mode_t rm)
{
    switch (rm) {
    case RM_RNE: softfloat_roundingMode = softfloat_round_near_even; break;
    case RM_RTZ: softfloat_roundingMode = softfloat_round_minMag;    break;
    case RM_RDN: softfloat_roundingMode = softfloat_round_min;       break;
    case RM_RUP: softfloat_roundingMode = softfloat_round_max;       break;
    case RM_RMM: softfloat_roundingMode = softfloat_round_near_maxMag; break;
    default:     softfloat_roundingMode = softfloat_round_near_even; break;
    }
    softfloat_exceptionFlags = 0;
}

static uint8_t get_flags()
{
    uint8_t f = 0;
    if (softfloat_exceptionFlags & softfloat_flag_invalid)   f |= FLAG_NV;
    if (softfloat_exceptionFlags & softfloat_flag_infinite)  f |= FLAG_DZ;
    if (softfloat_exceptionFlags & softfloat_flag_overflow)  f |= FLAG_OF;
    if (softfloat_exceptionFlags & softfloat_flag_underflow) f |= FLAG_UF;
    if (softfloat_exceptionFlags & softfloat_flag_inexact)   f |= FLAG_NX;
    return f;
}

/* -------------------------------------------------------------------------
 * NaN boxing helpers
 * ------------------------------------------------------------------------- */

static float32_t unbox_f32(uint64_t reg, int riscv_mode)
{
    float32_t r;
    if (riscv_mode && (reg >> 32) != 0xFFFFFFFFu)
        r.v = CANON_QNAN_F32;   /* unboxed → canonical qNaN */
    else
        r.v = (uint32_t)reg;
    return r;
}

static float64_t as_f64(uint64_t reg)
{
    float64_t r; r.v = reg; return r;
}

/* Canonicalize NaN in RISC-V mode */
static uint32_t canon_nan_f32(uint32_t b, int riscv)
{
    if (riscv && is_nan_f32(b)) return CANON_QNAN_F32;
    return b;
}
static uint64_t canon_nan_f64(uint64_t b, int riscv)
{
    if (riscv && is_nan_f64(b)) return CANON_QNAN_F64;
    return b;
}

/* -------------------------------------------------------------------------
 * FMIN / FMAX helpers (IEEE 754-2008 minNum/maxNum for RISC-V)
 * ------------------------------------------------------------------------- */

static int is_nan_f32_s(uint32_t b)   /* signalling NaN */
{ return (b & 0x7FC00000u) == 0x7F800000u && (b & 0x3FFFFFu) != 0; }
static int is_nan_f64_s(uint64_t b)
{ return (b & 0x7FF8000000000000ULL) == 0x7FF0000000000000ULL
      && (b & 0x0007FFFFFFFFFFFFull) != 0; }

static ref_result_t minmax_f32(uint32_t a, uint32_t b, int is_max, int riscv)
{
    ref_result_t r;
    int a_nan = is_nan_f32(a), b_nan = is_nan_f32(b);
    r.flags = (is_nan_f32_s(a) || is_nan_f32_s(b)) ? FLAG_NV : 0;

    if (a_nan && b_nan)      { r.result = CANON_QNAN_F32; return r; }
    if (riscv) {
        if (a_nan)           { r.result = b; return r; }
        if (b_nan)           { r.result = a; return r; }
    } else {
        if (a_nan || b_nan)  { r.result = CANON_QNAN_F32; return r; }
    }

    /* Both ±0: sign selection per IEEE 754-2019 §5.3.1 */
    int a_z = (a & 0x7FFFFFFFu) == 0, b_z = (b & 0x7FFFFFFFu) == 0;
    if (a_z && b_z) {
        int as = a >> 31, bs = b >> 31;
        r.result = is_max ? (a & b) : (a | b);  /* AND/OR sign bits */
        return r;
    }

    float32_t fa; fa.v = a;
    float32_t fb; fb.v = b;
    set_rm(RM_RNE);
    int lt = f32_lt(fa, fb);
    r.result = (is_max ? !lt : lt) ? a : b;
    return r;
}

static ref_result_t minmax_f64(uint64_t a, uint64_t b, int is_max, int riscv)
{
    ref_result_t r;
    int a_nan = is_nan_f64(a), b_nan = is_nan_f64(b);
    r.flags = (is_nan_f64_s(a) || is_nan_f64_s(b)) ? FLAG_NV : 0;

    if (a_nan && b_nan)      { r.result = CANON_QNAN_F64; return r; }
    if (riscv) {
        if (a_nan)           { r.result = b; return r; }
        if (b_nan)           { r.result = a; return r; }
    } else {
        if (a_nan || b_nan)  { r.result = CANON_QNAN_F64; return r; }
    }

    int a_z = (a & 0x7FFFFFFFFFFFFFFFull) == 0;
    int b_z = (b & 0x7FFFFFFFFFFFFFFFull) == 0;
    if (a_z && b_z) {
        r.result = is_max ? (a & b) : (a | b);
        return r;
    }

    float64_t fa; fa.v = a;
    float64_t fb; fb.v = b;
    set_rm(RM_RNE);
    int lt = f64_lt(fa, fb);
    r.result = (is_max ? !lt : lt) ? a : b;
    return r;
}

/* -------------------------------------------------------------------------
 * FCLASS helper
 * ------------------------------------------------------------------------- */

static uint32_t fclass_f32(uint32_t b)
{
    int sign = b >> 31;
    uint32_t exp  = (b >> 23) & 0xFF;
    uint32_t mant = b & 0x7FFFFF;
    if (exp == 0xFF && mant != 0)
        return (mant & 0x400000) ? 0x200 : 0x100; /* qNaN / sNaN */
    if (exp == 0xFF)   return sign ? 0x001 : 0x080; /* ±inf */
    if (exp == 0)
        return mant == 0 ? (sign ? 0x008 : 0x010)   /* ±0 */
                         : (sign ? 0x004 : 0x020);   /* ±subnormal */
    return sign ? 0x002 : 0x040;                     /* ±normal */
}

static uint32_t fclass_f64(uint64_t b)
{
    int sign = (int)(b >> 63);
    uint64_t exp  = (b >> 52) & 0x7FF;
    uint64_t mant = b & 0x000FFFFFFFFFFFFFull;
    if (exp == 0x7FF && mant != 0)
        return (mant & 0x0008000000000000ull) ? 0x200 : 0x100;
    if (exp == 0x7FF) return sign ? 0x001 : 0x080;
    if (exp == 0)
        return mant == 0 ? (sign ? 0x008 : 0x010)
                         : (sign ? 0x004 : 0x020);
    return sign ? 0x002 : 0x040;
}

/* -------------------------------------------------------------------------
 * FSGNJ
 * ------------------------------------------------------------------------- */

static uint32_t sgnj_f32(uint32_t a, uint32_t b, uint8_t mod)
{
    int bs = b >> 31, as_ = a >> 31;
    int ns;
    switch (mod & 3) {
    case 0: ns = bs;        break;  /* FSGNJ  */
    case 1: ns = bs ^ 1;   break;  /* FSGNJN */
    case 2: ns = as_ ^ bs; break;  /* FSGNJX */
    default: ns = bs;
    }
    return (a & 0x7FFFFFFFu) | ((uint32_t)ns << 31);
}

static uint64_t sgnj_f64(uint64_t a, uint64_t b, uint8_t mod)
{
    int bs = (int)(b >> 63), as_ = (int)(a >> 63);
    int ns;
    switch (mod & 3) {
    case 0: ns = bs;        break;
    case 1: ns = bs ^ 1;   break;
    case 2: ns = as_ ^ bs; break;
    default: ns = bs;
    }
    return (a & 0x7FFFFFFFFFFFFFFFull) | ((uint64_t)ns << 63);
}

/* -------------------------------------------------------------------------
 * F2I: RISC-V saturating float→int conversion
 * For out-of-range / NaN: return INT_MAX / INT_MIN / UINT_MAX + NV flag.
 * ------------------------------------------------------------------------- */

static ref_result_t f2i_f32(uint32_t a, uint8_t mod, int_fmt_t int_fmt,
                             round_mode_t rm)
{
    ref_result_t r;
    int is_signed   = (mod & 1);    /* op_modify[0]=1 → signed */
    int is_64b      = (int_fmt == INT_FMT_64);
    set_rm(rm);
    float32_t fa; fa.v = a;

    if (is_64b) {
        if (is_signed) {
            int64_t v = f32_to_i64(fa, softfloat_roundingMode, true);
            r.result = (uint64_t)v;
        } else {
            uint64_t v = f32_to_ui64(fa, softfloat_roundingMode, true);
            r.result = v;
        }
    } else {
        if (is_signed) {
            int32_t v = f32_to_i32(fa, softfloat_roundingMode, true);
            r.result = (uint64_t)(int64_t)v;   /* sign-extend to 64 */
        } else {
            uint32_t v = f32_to_ui32(fa, softfloat_roundingMode, true);
            r.result = (uint64_t)v;
        }
    }
    r.flags = get_flags();
    return r;
}

static ref_result_t f2i_f64(uint64_t a, uint8_t mod, int_fmt_t int_fmt,
                             round_mode_t rm)
{
    ref_result_t r;
    int is_signed = (mod & 1);
    int is_64b    = (int_fmt == INT_FMT_64);
    set_rm(rm);
    float64_t fa; fa.v = a;

    if (is_64b) {
        if (is_signed) {
            int64_t v = f64_to_i64(fa, softfloat_roundingMode, true);
            r.result = (uint64_t)v;
        } else {
            uint64_t v = f64_to_ui64(fa, softfloat_roundingMode, true);
            r.result = v;
        }
    } else {
        if (is_signed) {
            int32_t v = f64_to_i32(fa, softfloat_roundingMode, true);
            r.result = (uint64_t)(int64_t)v;
        } else {
            uint32_t v = f64_to_ui32(fa, softfloat_roundingMode, true);
            r.result = (uint64_t)v;
        }
    }
    r.flags = get_flags();
    return r;
}

/* -------------------------------------------------------------------------
 * I2F
 * ------------------------------------------------------------------------- */

static ref_result_t i2f_f32(uint64_t a_raw, uint8_t mod, int_fmt_t int_fmt,
                             round_mode_t rm)
{
    ref_result_t r;
    int is_signed = (mod & 1);
    int is_64b    = (int_fmt == INT_FMT_64);
    set_rm(rm);
    float32_t res;

    if (is_64b) {
        if (is_signed) res = i64_to_f32((int64_t)a_raw);
        else           res = ui64_to_f32(a_raw);
    } else {
        if (is_signed) res = i32_to_f32((int32_t)(uint32_t)a_raw);
        else           res = ui32_to_f32((uint32_t)a_raw);
    }
    r.result = res.v;
    r.flags  = get_flags();
    return r;
}

static ref_result_t i2f_f64(uint64_t a_raw, uint8_t mod, int_fmt_t int_fmt,
                             round_mode_t rm)
{
    ref_result_t r;
    int is_signed = (mod & 1);
    int is_64b    = (int_fmt == INT_FMT_64);
    set_rm(rm);
    float64_t res;

    if (is_64b) {
        if (is_signed) res = i64_to_f64((int64_t)a_raw);
        else           res = ui64_to_f64(a_raw);
    } else {
        if (is_signed) res = i32_to_f64((int32_t)(uint32_t)a_raw);
        else           res = ui32_to_f64((uint32_t)a_raw);
    }
    r.result = res.v;
    r.flags  = get_flags();
    return r;
}

/* -------------------------------------------------------------------------
 * Main dispatch
 * ------------------------------------------------------------------------- */

ref_result_t ref_compute(fp_op_t      op,
                         uint8_t      op_modify,
                         fp_fmt_t     fmt,
                         int_fmt_t    int_fmt,
                         round_mode_t rm,
                         uint64_t     a,
                         uint64_t     b,
                         uint64_t     c,
                         int          riscv_mode)
{
    ref_result_t r = {0, 0};
    set_rm(rm);

    if (fmt == FMT_FP32) {
        /* ---------------------------------------------------------------- */
        /* FP32                                                              */
        /* ---------------------------------------------------------------- */
        float32_t fa = unbox_f32(a, riscv_mode);
        float32_t fb = unbox_f32(b, riscv_mode);
        float32_t fc = unbox_f32(c, riscv_mode);
        float32_t res;

        switch (op) {
        case OP_FADD:
            res = f32_add(fa, fb);
            r.result = canon_nan_f32(res.v, riscv_mode);
            r.flags  = get_flags();
            break;

        case OP_FMUL: {
            /* FMADD: op_modify[1] negates a (for FNMADD/FNMSUB) */
            float32_t fa2; fa2.v = fa.v ^ ((uint32_t)(op_modify >> 1) << 31);
            res = f32_add(fa, fb);    /* placeholder: handled below */
            /* Regular MUL */
            res = f32_mul(fa, fb);
            r.result = canon_nan_f32(res.v, riscv_mode);
            r.flags  = get_flags();
            break;
        }

        case OP_FDIV:
            if (op_modify & 1) {           /* sqrt */
                res = f32_sqrt(fa);
            } else {
                res = f32_div(fa, fb);
            }
            r.result = canon_nan_f32(res.v, riscv_mode);
            r.flags  = get_flags();
            break;

        case OP_FMADD: {
            /* op_modify[1]=1 → negate a (FNMADD/FNMSUB) */
            float32_t fa2; fa2.v = fa.v ^ ((uint32_t)((op_modify >> 1) & 1) << 31);
            /* op_modify[0]=1 → subtract (FMSUB/FNMSUB) */
            float32_t fc2; fc2.v = fc.v ^ ((uint32_t)(op_modify & 1) << 31);
            res = f32_mulAdd(fa2, fb, fc2);
            r.result = canon_nan_f32(res.v, riscv_mode);
            r.flags  = get_flags();
            break;
        }

        case OP_FMIN:
            r = minmax_f32(fa.v, fb.v, 0, riscv_mode);
            if (riscv_mode && is_nan_f32(r.result)) r.result = CANON_QNAN_F32;
            break;
        case OP_FMAX:
            r = minmax_f32(fa.v, fb.v, 1, riscv_mode);
            if (riscv_mode && is_nan_f32(r.result)) r.result = CANON_QNAN_F32;
            break;

        case OP_FSGNJ:
            r.result = sgnj_f32(fa.v, fb.v, op_modify);
            r.flags  = 0;
            break;

        case OP_FCMP: {
            /* op_modify: 0=le 1=eq 2=lt  (matches fp_top) */
            int cmp;
            if (op_modify == 1)      cmp = f32_eq(fa, fb);
            else if (op_modify == 2) cmp = f32_lt(fa, fb);
            else                     cmp = f32_le(fa, fb);
            r.result = cmp;
            r.flags  = get_flags();
            break;
        }

        case OP_FCLASS:
            r.result = fclass_f32(fa.v);
            r.flags  = 0;
            break;

        case OP_F2I:
            r = f2i_f32(fa.v, op_modify, int_fmt, rm);
            break;

        case OP_I2F:
            r = i2f_f32(a, op_modify, int_fmt, rm);
            break;

        case OP_F2F:
            /* FP32 → FP64 widening (no precision loss) */
            {
                float64_t d = f32_to_f64(fa);
                r.result = d.v;
                r.flags  = get_flags();
            }
            break;

        default: break;
        }

    } else {
        /* ---------------------------------------------------------------- */
        /* FP64                                                              */
        /* ---------------------------------------------------------------- */
        float64_t fa = as_f64(a);
        float64_t fb = as_f64(b);
        float64_t fc = as_f64(c);
        float64_t res;

        switch (op) {
        case OP_FADD:
            res = f64_add(fa, fb);
            r.result = canon_nan_f64(res.v, riscv_mode);
            r.flags  = get_flags();
            break;

        case OP_FMUL:
            res = f64_mul(fa, fb);
            r.result = canon_nan_f64(res.v, riscv_mode);
            r.flags  = get_flags();
            break;

        case OP_FDIV:
            if (op_modify & 1) res = f64_sqrt(fa);
            else               res = f64_div(fa, fb);
            r.result = canon_nan_f64(res.v, riscv_mode);
            r.flags  = get_flags();
            break;

        case OP_FMADD: {
            float64_t fa2; fa2.v = fa.v ^ ((uint64_t)((op_modify >> 1) & 1) << 63);
            float64_t fc2; fc2.v = fc.v ^ ((uint64_t)(op_modify & 1) << 63);
            res = f64_mulAdd(fa2, fb, fc2);
            r.result = canon_nan_f64(res.v, riscv_mode);
            r.flags  = get_flags();
            break;
        }

        case OP_FMIN:
            r = minmax_f64(fa.v, fb.v, 0, riscv_mode);
            if (riscv_mode && is_nan_f64(r.result)) r.result = CANON_QNAN_F64;
            break;
        case OP_FMAX:
            r = minmax_f64(fa.v, fb.v, 1, riscv_mode);
            if (riscv_mode && is_nan_f64(r.result)) r.result = CANON_QNAN_F64;
            break;

        case OP_FSGNJ:
            r.result = sgnj_f64(fa.v, fb.v, op_modify);
            r.flags  = 0;
            break;

        case OP_FCMP: {
            int cmp;
            if (op_modify == 1)      cmp = f64_eq(fa, fb);
            else if (op_modify == 2) cmp = f64_lt(fa, fb);
            else                     cmp = f64_le(fa, fb);
            r.result = cmp;
            r.flags  = get_flags();
            break;
        }

        case OP_FCLASS:
            r.result = fclass_f64(fa.v);
            r.flags  = 0;
            break;

        case OP_F2I:
            r = f2i_f64(fa.v, op_modify, int_fmt, rm);
            break;

        case OP_I2F:
            r = i2f_f64(a, op_modify, int_fmt, rm);
            break;

        case OP_F2F:
            /* FP64 → FP32 narrowing */
            {
                float32_t s = f64_to_f32(fa);
                /* RISC-V: NaN box the FP32 result in a 64-bit register */
                r.result = riscv_mode
                    ? (0xFFFFFFFF00000000ULL | s.v)
                    : s.v;
                if (riscv_mode && is_nan_f32(s.v))
                    r.result = 0xFFFFFFFF00000000ULL | CANON_QNAN_F32;
                r.flags  = get_flags();
            }
            break;

        default: break;
        }
    }

    return r;
}
