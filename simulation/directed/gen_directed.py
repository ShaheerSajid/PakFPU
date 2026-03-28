#!/usr/bin/env python3
"""
gen_directed.py — Directed special-value test generator for PakFPU.

Generates test vectors covering all combinations of special-value classes
(±0, ±∞, sNaN, qNaN, ±subnormal, ±normal) for every supported operation,
across all 5 rounding modes.

Output format matches the existing Berkeley TestFloat hex format consumed by
the Verilator testbench:
    FP32 binary op:   XXXXXXXX XXXXXXXX XXXXXXXX XX
    FP64 binary op:   XXXXXXXXXXXXXXXX XXXXXXXXXXXXXXXX XXXXXXXXXXXXXXXX XX
    1-input op:       XXXXXXXX XXXXXXXX XX
    3-input (FMA):    A B C RESULT FLAGS

Usage:
    python3 gen_directed.py --fmt fp32 --op add --rm 0 > vectors.txt
    python3 gen_directed.py --fmt fp32 --all > directed_fp32.txt
    python3 gen_directed.py --fmt fp64 --all > directed_fp64.txt
    python3 gen_directed.py --fmt fp32 --op nanbox  # NaN boxing tests (RISC-V)

Flags byte bit layout (IEEE 754 / RISC-V fflags): NV DZ OF UF NX = bits 4..0
"""

import argparse
import itertools
import math
import struct
import sys

# ---------------------------------------------------------------------------
# IEEE 754 bit patterns for special values
# ---------------------------------------------------------------------------

FP32_BIAS = 127
FP64_BIAS = 1023

def _f32(sign, exp, mant):
    """Pack a raw FP32 bit pattern."""
    return ((sign & 1) << 31) | ((exp & 0xFF) << 23) | (mant & 0x7FFFFF)

def _f64(sign, exp, mant):
    """Pack a raw FP64 bit pattern."""
    return ((sign & 1) << 63) | ((exp & 0x7FF) << 52) | (mant & 0x000FFFFFFFFFFFFF)

# Special-value representatives (sign=0 and sign=1 variants where relevant)
def special_values_fp32():
    return {
        '+0':        _f32(0, 0,    0),
        '-0':        _f32(1, 0,    0),
        '+inf':      _f32(0, 0xFF, 0),
        '-inf':      _f32(1, 0xFF, 0),
        'qnan':      _f32(0, 0xFF, 0x400000),   # canonical qNaN
        'snan':      _f32(0, 0xFF, 0x200000),   # sNaN (quiet bit clear, payload non-zero)
        'qnan2':     _f32(1, 0xFF, 0x600000),   # qNaN with sign bit set
        '+sub':      _f32(0, 0,    1),           # smallest positive subnormal
        '-sub':      _f32(1, 0,    1),           # smallest negative subnormal
        '+sub_big':  _f32(0, 0,    0x7FFFFF),   # largest subnormal
        '-sub_big':  _f32(1, 0,    0x7FFFFF),
        '+norm_min': _f32(0, 1,    0),           # smallest positive normal
        '-norm_min': _f32(1, 1,    0),
        '+norm':     _f32(0, 127,  0x400000),   # 1.5 (mid-range normal)
        '-norm':     _f32(1, 127,  0x400000),   # -1.5
        '+norm_max': _f32(0, 254,  0x7FFFFF),   # largest normal (FLT_MAX)
        '-norm_max': _f32(1, 254,  0x7FFFFF),
        # Boundary cases for FCVT overflow
        'fcvt_ovf':  _f32(0, 158,  0),          # 2^32, overflows INT32/UINT32
    }

def special_values_fp64():
    return {
        '+0':        _f64(0, 0,       0),
        '-0':        _f64(1, 0,       0),
        '+inf':      _f64(0, 0x7FF,   0),
        '-inf':      _f64(1, 0x7FF,   0),
        'qnan':      _f64(0, 0x7FF,   0x8000000000000),  # canonical qNaN
        'snan':      _f64(0, 0x7FF,   0x4000000000000),  # sNaN
        'qnan2':     _f64(1, 0x7FF,   0xC000000000000),
        '+sub':      _f64(0, 0,       1),
        '-sub':      _f64(1, 0,       1),
        '+sub_big':  _f64(0, 0,       0x000FFFFFFFFFFFFF),
        '-sub_big':  _f64(1, 0,       0x000FFFFFFFFFFFFF),
        '+norm_min': _f64(0, 1,       0),
        '-norm_min': _f64(1, 1,       0),
        '+norm':     _f64(0, 1023,    0x8000000000000),  # 1.5
        '-norm':     _f64(1, 1023,    0x8000000000000),
        '+norm_max': _f64(0, 2046,    0x000FFFFFFFFFFFFF),
        '-norm_max': _f64(1, 2046,    0x000FFFFFFFFFFFFF),
        'fcvt_ovf':  _f64(0, 1086,    0),               # 2^63
    }

# ---------------------------------------------------------------------------
# Python-side IEEE 754 arithmetic (via struct round-trip for correct bits)
# ---------------------------------------------------------------------------

NV = 0x10  # Invalid
DZ = 0x08  # Divide by zero
OF = 0x04  # Overflow
UF = 0x02  # Underflow
NX = 0x01  # Inexact

def bits_to_f32(b):
    return struct.unpack('f', struct.pack('I', b & 0xFFFFFFFF))[0]

def f32_to_bits(f):
    return struct.unpack('I', struct.pack('f', f))[0]

def bits_to_f64(b):
    return struct.unpack('d', struct.pack('Q', b & 0xFFFFFFFFFFFFFFFF))[0]

def f64_to_bits(f):
    return struct.unpack('Q', struct.pack('d', f))[0]

def is_nan_bits32(b):  return (b & 0x7F800000) == 0x7F800000 and (b & 0x7FFFFF) != 0
def is_inf_bits32(b):  return (b & 0x7FFFFFFF) == 0x7F800000
def is_zero_bits32(b): return (b & 0x7FFFFFFF) == 0
def is_nan_bits64(b):  return (b & 0x7FF0000000000000) == 0x7FF0000000000000 and (b & 0x000FFFFFFFFFFFFF) != 0
def is_inf_bits64(b):  return (b & 0x7FFFFFFFFFFFFFFF) == 0x7FF0000000000000
def is_zero_bits64(b): return (b & 0x7FFFFFFFFFFFFFFF) == 0

CANON_QNAN32 = _f32(0, 0xFF, 0x400000)
CANON_QNAN64 = _f64(0, 0x7FF, 0x8000000000000)

def is_snan32(b): return (b & 0x7FC00000) == 0x7F800000 and (b & 0x3FFFFF) != 0
def is_snan64(b): return (b & 0x7FF8000000000000) == 0x7FF0000000000000 and (b & 0x0007FFFFFFFFFFFF) != 0
def is_qnan32(b): return (b & 0xFF800000) == 0x7FC00000
def is_qnan64(b): return (b & 0xFFF8000000000000) == 0x7FF8000000000000

# ---------------------------------------------------------------------------
# Rule-based reference for special-value combinations
# ---------------------------------------------------------------------------

def ref_add_sub_fp32(a_bits, b_bits, sub, rm):
    """Compute expected (result_bits, flags) for FP32 add/sub."""
    flags = 0
    if is_snan32(a_bits) or is_snan32(b_bits):
        flags |= NV
    if is_nan32_any(a_bits):
        return (CANON_QNAN32, flags | NV) if is_snan32(a_bits) else (CANON_QNAN32, flags)
    if is_nan32_any(b_bits):
        return (CANON_QNAN32, flags | NV) if is_snan32(b_bits) else (CANON_QNAN32, flags)

    b_eff = b_bits ^ (0x80000000 if sub else 0)
    a_sign = (a_bits >> 31) & 1
    b_sign = (b_eff >> 31) & 1

    # inf ± inf with same sign = inf, opposite sign = invalid
    if is_inf_bits32(a_bits) and is_inf_bits32(b_eff):
        if a_sign == b_sign:
            return (a_bits, 0)
        else:
            return (CANON_QNAN32, NV)
    if is_inf_bits32(a_bits): return (a_bits, 0)
    if is_inf_bits32(b_eff):  return (b_eff, 0)

    # Use Python float arithmetic for normal cases (covers ±0, subnormals, normals)
    a = bits_to_f32(a_bits)
    b_val = bits_to_f32(b_eff)
    try:
        result = a + b_val
    except Exception:
        return (CANON_QNAN32, NV)
    r_bits = f32_to_bits(result)
    # Exact zero: IEEE 754-2019 zero-sum sign = +0 except RDN→-0
    if is_zero_bits32(r_bits) and not is_zero_bits32(a_bits) and not is_zero_bits32(b_eff):
        r_bits = _f32(1 if rm == 2 else 0, 0, 0)
    return (r_bits, NX if result != 0.0 and r_bits != a_bits else 0)

def is_nan32_any(b): return is_nan_bits32(b)
def is_nan64_any(b): return is_nan_bits64(b)


def ref_op_fp32(op, a_bits, b_bits, c_bits, rm, riscv_mode=False):
    """
    Returns (result_bits_32, flags_byte) for FP32 operations.
    Uses rule-based computation for special classes; falls back to Python
    float arithmetic for normal+normal cases.

    This is the fast path for directed special-value tests.  For exhaustive
    random arithmetic testing the ref_model C++ wrapper (linked against
    Berkeley SoftFloat) is used instead.
    """
    flags = 0
    a_nan = is_nan32_any(a_bits)
    b_nan = is_nan32_any(b_bits)
    c_nan = is_nan32_any(c_bits)
    a_snan = is_snan32(a_bits)
    b_snan = is_snan32(b_bits)
    c_snan = is_snan32(c_bits)
    a_inf  = is_inf_bits32(a_bits)
    b_inf  = is_inf_bits32(b_bits)
    a_zero = is_zero_bits32(a_bits)
    b_zero = is_zero_bits32(b_bits)
    a_sign = (a_bits >> 31) & 1
    b_sign = (b_bits >> 31) & 1

    if op in ('add', 'sub'):
        sub = (op == 'sub')
        b_eff = b_bits ^ (0x80000000 if sub else 0)
        b_eff_sign = (b_eff >> 31) & 1
        if a_snan or b_snan:       flags |= NV
        if a_nan:                  return (CANON_QNAN32, flags | NV if a_snan else flags)
        if b_nan:                  return (CANON_QNAN32, flags | NV if b_snan else flags)
        if a_inf and is_inf_bits32(b_eff):
            if a_sign == b_eff_sign: return (a_bits, 0)
            else:                    return (CANON_QNAN32, NV)
        if a_inf:                  return (a_bits, 0)
        if is_inf_bits32(b_eff):   return (b_eff, 0)
        a_f = bits_to_f32(a_bits); b_f = bits_to_f32(b_eff)
        r = a_f + b_f
        rb = f32_to_bits(r)
        if is_zero_bits32(rb) and not (is_zero_bits32(a_bits) and is_zero_bits32(b_eff)):
            rb = _f32(1 if rm == 2 else 0, 0, 0)
        return (rb, 0)  # flags approximated; SoftFloat ref model gives exact flags

    elif op == 'mul':
        if a_snan or b_snan:       flags |= NV
        if a_nan:                  return (CANON_QNAN32, flags | NV if a_snan else flags)
        if b_nan:                  return (CANON_QNAN32, flags | NV if b_snan else flags)
        if (a_inf and b_zero) or (a_zero and b_inf):
            return (CANON_QNAN32, NV)
        if a_inf or b_inf:
            return (_f32(a_sign ^ b_sign, 0xFF, 0), 0)
        if a_zero or b_zero:
            return (_f32(a_sign ^ b_sign, 0, 0), 0)
        r = bits_to_f32(a_bits) * bits_to_f32(b_bits)
        return (f32_to_bits(r), 0)

    elif op == 'div':
        if a_snan or b_snan:       flags |= NV
        if a_nan:                  return (CANON_QNAN32, flags | NV if a_snan else flags)
        if b_nan:                  return (CANON_QNAN32, flags | NV if b_snan else flags)
        if a_inf and b_inf:        return (CANON_QNAN32, NV)
        if a_zero and b_zero:      return (CANON_QNAN32, NV)
        if a_inf:                  return (_f32(a_sign ^ b_sign, 0xFF, 0), 0)
        if b_inf:                  return (_f32(a_sign ^ b_sign, 0, 0), 0)
        if b_zero:                 return (_f32(a_sign ^ b_sign, 0xFF, 0), DZ)
        if a_zero:                 return (_f32(a_sign ^ b_sign, 0, 0), 0)
        r = bits_to_f32(a_bits) / bits_to_f32(b_bits)
        return (f32_to_bits(r), 0)

    elif op == 'sqrt':
        if a_snan:                 return (CANON_QNAN32, NV)
        if a_nan:                  return (CANON_QNAN32, 0)
        if a_inf and a_sign == 0:  return (a_bits, 0)       # sqrt(+inf) = +inf
        if a_inf and a_sign == 1:  return (CANON_QNAN32, NV) # sqrt(-inf) = NaN
        if a_zero:                 return (a_bits, 0)         # sqrt(±0) = ±0
        if a_sign:                 return (CANON_QNAN32, NV)  # sqrt(negative) = NaN
        r = math.sqrt(bits_to_f32(a_bits))
        return (f32_to_bits(r), 0)

    elif op in ('min', 'max'):
        any_snan = a_snan or b_snan
        if any_snan: flags |= NV
        if a_nan and b_nan:        return (CANON_QNAN32, flags)
        if riscv_mode:
            # IEEE 754-2008 minNum/maxNum: return non-NaN when one is NaN
            if a_nan:              return (b_bits, flags)
            if b_nan:              return (a_bits, flags)
        else:
            # IEEE 754-2019 minimum/maximum: NaN propagates
            if a_nan or b_nan:     return (CANON_QNAN32, flags)
        # Both zero: sign handling
        if a_zero and b_zero:
            if op == 'min':
                return (_f32(a_sign | b_sign, 0, 0), flags)
            else:
                return (_f32(a_sign & b_sign, 0, 0), flags)
        a_f = bits_to_f32(a_bits); b_f = bits_to_f32(b_bits)
        if op == 'min':
            return (a_bits if a_f <= b_f else b_bits, flags)
        else:
            return (a_bits if a_f >= b_f else b_bits, flags)

    elif op in ('le', 'lt', 'eq'):
        if a_snan or b_snan or (op != 'eq' and (a_nan or b_nan)):
            flags |= NV
        if a_nan or b_nan:
            return (0, flags)
        a_f = bits_to_f32(a_bits); b_f = bits_to_f32(b_bits)
        if op == 'le':   res = int(a_f <= b_f)
        elif op == 'lt': res = int(a_f < b_f)
        else:            res = int(a_f == b_f)
        return (res, flags)

    elif op == 'sgnj':
        r = (a_bits & 0x7FFFFFFF) | (b_sign << 31)
        return (r, 0)
    elif op == 'sgnjn':
        r = (a_bits & 0x7FFFFFFF) | ((b_sign ^ 1) << 31)
        return (r, 0)
    elif op == 'sgnjx':
        r = (a_bits & 0x7FFFFFFF) | ((a_sign ^ b_sign) << 31)
        return (r, 0)

    elif op == 'classify':
        if is_snan32(a_bits):      cls = 0x100
        elif is_qnan32(a_bits):    cls = 0x200
        elif is_inf_bits32(a_bits):
            cls = 0x001 if a_sign else 0x080
        elif is_zero_bits32(a_bits):
            cls = 0x008 if a_sign else 0x010
        elif (a_bits & 0x7F800000) == 0:  # subnormal
            cls = 0x004 if a_sign else 0x020
        else:
            cls = 0x002 if a_sign else 0x040
        return (cls, 0)

    return (CANON_QNAN32, NV)  # fallback


def ref_op_fp64(op, a_bits, b_bits, c_bits, rm, riscv_mode=False):
    """Same as ref_op_fp32 but for FP64."""
    flags = 0
    a_nan  = is_nan64_any(a_bits)
    b_nan  = is_nan64_any(b_bits)
    a_snan = is_snan64(a_bits)
    b_snan = is_snan64(b_bits)
    a_inf  = is_inf_bits64(a_bits)
    b_inf  = is_inf_bits64(b_bits)
    a_zero = is_zero_bits64(a_bits)
    b_zero = is_zero_bits64(b_bits)
    a_sign = (a_bits >> 63) & 1
    b_sign = (b_bits >> 63) & 1

    if op in ('add', 'sub'):
        sub = (op == 'sub')
        b_eff = b_bits ^ (0x8000000000000000 if sub else 0)
        b_eff_sign = (b_eff >> 63) & 1
        if a_snan or b_snan: flags |= NV
        if a_nan: return (CANON_QNAN64, flags | NV if a_snan else flags)
        if b_nan: return (CANON_QNAN64, flags | NV if b_snan else flags)
        if a_inf and is_inf_bits64(b_eff):
            if a_sign == b_eff_sign: return (a_bits, 0)
            else: return (CANON_QNAN64, NV)
        if a_inf: return (a_bits, 0)
        if is_inf_bits64(b_eff): return (b_eff, 0)
        a_f = bits_to_f64(a_bits); b_f = bits_to_f64(b_eff)
        r = a_f + b_f
        rb = f64_to_bits(r)
        if is_zero_bits64(rb) and not (is_zero_bits64(a_bits) and is_zero_bits64(b_eff)):
            rb = _f64(1 if rm == 2 else 0, 0, 0)
        return (rb, 0)

    elif op == 'mul':
        if a_snan or b_snan: flags |= NV
        if a_nan: return (CANON_QNAN64, flags | NV if a_snan else flags)
        if b_nan: return (CANON_QNAN64, flags | NV if b_snan else flags)
        if (a_inf and b_zero) or (a_zero and b_inf): return (CANON_QNAN64, NV)
        if a_inf or b_inf: return (_f64(a_sign ^ b_sign, 0x7FF, 0), 0)
        if a_zero or b_zero: return (_f64(a_sign ^ b_sign, 0, 0), 0)
        r = bits_to_f64(a_bits) * bits_to_f64(b_bits)
        return (f64_to_bits(r), 0)

    elif op == 'div':
        if a_snan or b_snan: flags |= NV
        if a_nan: return (CANON_QNAN64, flags | NV if a_snan else flags)
        if b_nan: return (CANON_QNAN64, flags | NV if b_snan else flags)
        if a_inf and b_inf: return (CANON_QNAN64, NV)
        if a_zero and b_zero: return (CANON_QNAN64, NV)
        if a_inf: return (_f64(a_sign ^ b_sign, 0x7FF, 0), 0)
        if b_inf: return (_f64(a_sign ^ b_sign, 0, 0), 0)
        if b_zero: return (_f64(a_sign ^ b_sign, 0x7FF, 0), DZ)
        if a_zero: return (_f64(a_sign ^ b_sign, 0, 0), 0)
        r = bits_to_f64(a_bits) / bits_to_f64(b_bits)
        return (f64_to_bits(r), 0)

    elif op == 'sqrt':
        if a_snan: return (CANON_QNAN64, NV)
        if a_nan:  return (CANON_QNAN64, 0)
        if a_inf and a_sign == 0: return (a_bits, 0)
        if a_inf and a_sign == 1: return (CANON_QNAN64, NV)
        if a_zero: return (a_bits, 0)
        if a_sign: return (CANON_QNAN64, NV)
        r = math.sqrt(bits_to_f64(a_bits))
        return (f64_to_bits(r), 0)

    elif op in ('min', 'max'):
        any_snan = a_snan or b_snan
        if any_snan: flags |= NV
        if a_nan and b_nan: return (CANON_QNAN64, flags)
        if riscv_mode:
            if a_nan: return (b_bits, flags)
            if b_nan: return (a_bits, flags)
        else:
            if a_nan or b_nan: return (CANON_QNAN64, flags)
        if a_zero and b_zero:
            if op == 'min': return (_f64(a_sign | b_sign, 0, 0), flags)
            else:           return (_f64(a_sign & b_sign, 0, 0), flags)
        a_f = bits_to_f64(a_bits); b_f = bits_to_f64(b_bits)
        if op == 'min': return (a_bits if a_f <= b_f else b_bits, flags)
        else:           return (a_bits if a_f >= b_f else b_bits, flags)

    elif op in ('le', 'lt', 'eq'):
        if a_snan or b_snan or (op != 'eq' and (a_nan or b_nan)):
            flags |= NV
        if a_nan or b_nan: return (0, flags)
        a_f = bits_to_f64(a_bits); b_f = bits_to_f64(b_bits)
        if op == 'le':   res = int(a_f <= b_f)
        elif op == 'lt': res = int(a_f < b_f)
        else:            res = int(a_f == b_f)
        return (res, flags)

    elif op == 'sgnj':
        r = (a_bits & 0x7FFFFFFFFFFFFFFF) | (b_sign << 63)
        return (r, 0)
    elif op == 'sgnjn':
        r = (a_bits & 0x7FFFFFFFFFFFFFFF) | ((b_sign ^ 1) << 63)
        return (r, 0)
    elif op == 'sgnjx':
        r = (a_bits & 0x7FFFFFFFFFFFFFFF) | ((a_sign ^ b_sign) << 63)
        return (r, 0)

    elif op == 'classify':
        if is_snan64(a_bits):     cls = 0x100
        elif is_qnan64(a_bits):   cls = 0x200
        elif is_inf_bits64(a_bits):
            cls = 0x001 if a_sign else 0x080
        elif is_zero_bits64(a_bits):
            cls = 0x008 if a_sign else 0x010
        elif (a_bits & 0x7FF0000000000000) == 0:
            cls = 0x004 if a_sign else 0x020
        else:
            cls = 0x002 if a_sign else 0x040
        return (cls, 0)

    return (CANON_QNAN64, NV)


# ---------------------------------------------------------------------------
# NaN-boxing tests (RISC-V mode only)
# ---------------------------------------------------------------------------

def gen_nanbox_tests():
    """
    Generate NaN boxing test cases for FP32-in-FP64-register inputs.
    These test that fp_top with RISCV_MODE=1 treats unboxed inputs as qNaN.
    Each line: A_64 B_64 EXPECTED_32 FLAGS (for FADD FP32)
    """
    lines = []
    good_box = 0xFFFFFFFF00000000  # correct box for +1.0

    fp32_1p0 = _f32(0, 127, 0)          # +1.0 FP32
    fp32_2p0 = _f32(0, 128, 0)          # +2.0 FP32

    unboxed_patterns = [
        0x0000000000000000,  # upper bits = 0 (no box)
        0x00000000FFFFFFFF,  # lower bits all-1 but upper 0
        0x7FFFFFFF00000000,  # upper bits almost all-1
        0xFFFFFFFE00000000,  # one bit off
        0x1234567800000000,  # arbitrary bad upper
    ]

    for bad_upper in unboxed_patterns:
        a_bad = bad_upper | fp32_1p0    # unboxed a
        b_good = good_box | fp32_2p0    # properly boxed b
        # a is unboxed → treated as qNaN → result is qNaN, NV flagged
        lines.append(f'{a_bad:016x} {b_good:016x} {CANON_QNAN32:08x} {NV:02x}')

        a_good = good_box | fp32_1p0
        b_bad  = bad_upper | fp32_2p0   # unboxed b
        lines.append(f'{a_good:016x} {b_bad:016x} {CANON_QNAN32:08x} {NV:02x}')

    return lines


# ---------------------------------------------------------------------------
# FCVT boundary cases
# ---------------------------------------------------------------------------

def gen_fcvt_boundary_fp32():
    """
    Float→Int conversion boundary tests for FP32.
    RISC-V specifies saturating behaviour with NV flag on out-of-range inputs.
    Format: A_32  EXPECTED_INT FLAGS   (for FCVT.W.S / FCVT.WU.S)
    """
    lines = []
    # Signed 32-bit: INT32_MAX = 2^31-1, INT32_MIN = -2^31
    INT32_MAX = 0x7FFFFFFF
    INT32_MIN = 0x80000000  # as unsigned representation of -2^31
    # Unsigned 32-bit: UINT32_MAX = 2^32-1
    UINT32_MAX = 0xFFFFFFFF

    cases = [
        # (a_bits, expected_signed_int, expected_unsigned_int, flags)
        (_f32(0, 0xFF, 0),            INT32_MAX,  UINT32_MAX, NV),  # +inf → max
        (_f32(1, 0xFF, 0),            INT32_MIN,  0,          NV),  # -inf → min
        (CANON_QNAN32,                INT32_MAX,  UINT32_MAX, NV),  # NaN  → max
        (_f32(0, 158, 0),             INT32_MAX,  UINT32_MAX, NV),  # 2^32 overflow
        (_f32(0, 157, 0),             INT32_MAX,  0x80000000, NV),  # 2^31 signed overflow
        (_f32(0, 127, 0),             1,          1,          0),   # 1.0 (exact)
        (_f32(0, 126, 0),             0,          0,          NX),  # 0.5 rounds to 0 (RNE)
        (_f32(1, 127, 0),             0xFFFFFFFF, 0,          NV),  # -1.0 unsigned → 0 with NV
    ]
    for (a_bits, exp_s, exp_u, flg) in cases:
        lines.append(f'# FCVT.W.S  (signed):   {a_bits:08x} -> {exp_s:08x} flags={flg:02x}')
        lines.append(f'{a_bits:08x} {exp_s:08x} {flg:02x}')
        lines.append(f'# FCVT.WU.S (unsigned): {a_bits:08x} -> {exp_u:08x} flags={flg:02x}')
        lines.append(f'{a_bits:08x} {exp_u:08x} {flg:02x}')
    return lines


# ---------------------------------------------------------------------------
# Main generator
# ---------------------------------------------------------------------------

def gen_binary_op(fmt, op, rm, riscv_mode, check_flags=False):
    """Yield (a, b, expected, flags) tuples for all special-value pairs."""
    if fmt == 'fp32':
        sv = special_values_fp32()
        ref = lambda a, b: ref_op_fp32(op, a, b, 0, rm, riscv_mode)
        width = 8
    else:
        sv = special_values_fp64()
        ref = lambda a, b: ref_op_fp64(op, a, b, 0, rm, riscv_mode)
        width = 16

    for (na, a), (nb, b) in itertools.product(sv.items(), sv.items()):
        try:
            result, flags = ref(a, b)
        except Exception as e:
            result, flags = (CANON_QNAN32 if fmt == 'fp32' else CANON_QNAN64), NV
        yield (a, b, result, flags)


def gen_unary_op(fmt, op, rm, riscv_mode):
    if fmt == 'fp32':
        sv = special_values_fp32()
        ref = lambda a: ref_op_fp32(op, a, 0, 0, rm, riscv_mode)
        width = 8
    else:
        sv = special_values_fp64()
        ref = lambda a: ref_op_fp64(op, a, 0, 0, rm, riscv_mode)
        width = 16

    for (na, a) in sv.items():
        try:
            result, flags = ref(a)
        except Exception:
            result, flags = (CANON_QNAN32 if fmt == 'fp32' else CANON_QNAN64), NV
        yield (a, result, flags)


def format_line_binary(fmt, a, b, result, flags):
    if fmt == 'fp32':
        return f'{a:08x} {b:08x} {result:08x} {flags:02x}'
    else:
        return f'{a:016x} {b:016x} {result:016x} {flags:02x}'


def format_line_unary(fmt, a, result, flags):
    if fmt == 'fp32':
        return f'{a:08x} {result:08x} {flags:02x}'
    else:
        return f'{a:016x} {result:016x} {flags:02x}'


BINARY_OPS  = ['add', 'sub', 'mul', 'div', 'min', 'max',
                'le', 'lt', 'eq', 'sgnj', 'sgnjn', 'sgnjx']
UNARY_OPS   = ['sqrt', 'classify']


def main():
    p = argparse.ArgumentParser(description='PakFPU directed test generator')
    p.add_argument('--fmt',        choices=['fp32', 'fp64'], default='fp32')
    p.add_argument('--op',         default='all',
                   help='Operation (add/sub/mul/div/sqrt/min/max/le/lt/eq/'
                        'sgnj/sgnjn/sgnjx/classify/nanbox/fcvt_boundary/all)')
    p.add_argument('--rm',         type=int, default=0,
                   help='Rounding mode 0=RNE 1=RTZ 2=RDN 3=RUP 4=RMM')
    p.add_argument('--all-rm',     action='store_true',
                   help='Generate for all 5 rounding modes')
    p.add_argument('--riscv',      action='store_true',
                   help='Use RISC-V NaN semantics for min/max and nan boxing')
    p.add_argument('--no-flags',   action='store_true',
                   help='Do not check exception flags (use 00 placeholder)')
    args = p.parse_args()

    rms = list(range(5)) if args.all_rm else [args.rm]
    ops = (BINARY_OPS + UNARY_OPS) if args.op == 'all' else [args.op]

    for op in ops:
        for rm in rms:
            print(f'# op={op} fmt={args.fmt} rm={rm} riscv={args.riscv}',
                  file=sys.stderr)

            if op == 'nanbox':
                for line in gen_nanbox_tests():
                    print(line)
                continue

            if op == 'fcvt_boundary':
                for line in gen_fcvt_boundary_fp32():
                    print(line)
                continue

            if op in BINARY_OPS:
                for a, b, result, flags in gen_binary_op(
                        args.fmt, op, rm, args.riscv):
                    f = 0 if args.no_flags else flags
                    print(format_line_binary(args.fmt, a, b, result, f))
            elif op in UNARY_OPS:
                for a, result, flags in gen_unary_op(args.fmt, op, rm, args.riscv):
                    f = 0 if args.no_flags else flags
                    print(format_line_unary(args.fmt, a, result, f))


if __name__ == '__main__':
    main()
