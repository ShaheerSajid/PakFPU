
// fp_defs.svh — included inside each parameterized module body via `include.
// Requires the including module to have these localparams in scope:
//   FP_WIDTH, EXP_WIDTH, MANT_WIDTH  (derived from FP_FORMAT via fp_pkg).
//
// Defines parameterized types and classification functions that depend on
// the module's FP_FORMAT context:
//   - FP classification functions (is_normal, is_nan, fp_info, ...)
//   - Parameterized structs: fp_encoding_t, uround_res_t, round_res_t,
//     fp_encoding_fma_t, uround_res_fma_t
//
// Fixed-width types (fp32_encoding_t, fp64_encoding_t, fp32_info, fp64_info)
// live in fp_pkg.sv and are available via `import fp_pkg::*`.

function logic sign(logic [FP_WIDTH-1:0] val);
    return val[FP_WIDTH-1];
endfunction
function logic [EXP_WIDTH-1:0] exp(logic [FP_WIDTH-1:0] val);
    return val[FP_WIDTH-2-:EXP_WIDTH];
endfunction
function logic [MANT_WIDTH-1:0] mant(logic [FP_WIDTH-1:0] val);
    return val[FP_WIDTH-2-EXP_WIDTH:0];
endfunction
function logic is_minus(logic [FP_WIDTH-1:0] val);
    return sign(val);
endfunction
function logic is_normal(logic [FP_WIDTH-1:0] val);
    return (exp(val) >= 1) && (exp(val) <= (2**EXP_WIDTH-2));
endfunction
function logic is_subnormal(logic [FP_WIDTH-1:0] val);
    return (exp(val) == 0) && (mant(val) != 0);
endfunction
function logic is_zero(logic [FP_WIDTH-1:0] val);
    return val[FP_WIDTH-2:0] == 0;
endfunction
function logic is_inf(logic [FP_WIDTH-1:0] val);
    return exp(val) == (2**EXP_WIDTH-1) && mant(val) == 0;
endfunction
function logic is_nan(logic [FP_WIDTH-1:0] val);
    return exp(val) == (2**EXP_WIDTH-1) && mant(val) != 0;
endfunction
function logic is_signalling(logic [FP_WIDTH-1:0] val);
    return exp(val) == (2**EXP_WIDTH-1) && mant(val) != 0 && !val[FP_WIDTH-2-EXP_WIDTH];
endfunction
function logic is_quiet(logic [FP_WIDTH-1:0] val);
    return exp(val) == (2**EXP_WIDTH-1) && val[FP_WIDTH-2-EXP_WIDTH];
endfunction
function logic is_canonical(logic [FP_WIDTH-1:0] val);
    return is_finite(val) | is_inf(val) | (exp(val) == (2**EXP_WIDTH-1) && val[FP_WIDTH-2-EXP_WIDTH]);
endfunction
function logic is_finite(logic [FP_WIDTH-1:0] val);
    return is_zero(val) | is_subnormal(val) | is_normal(val);
endfunction

function fp_info_t fp_info(logic [FP_WIDTH-1:0] val);
    fp_info_t info;
    info = '0;
    info.is_minus       = is_minus(val);
    info.is_normal      = is_normal(val);
    info.is_subnormal   = is_subnormal(val);
    info.is_zero        = is_zero(val);
    info.is_inf         = is_inf(val);
    info.is_nan         = is_nan(val);
    info.is_signalling  = is_signalling(val);
    info.is_canonical   = is_canonical(val);
    info.is_finite      = is_finite(val);
    info.is_quiet       = is_quiet(val);
    return info;
endfunction

typedef struct packed {
    logic sign;
    logic [EXP_WIDTH-1:0] exp;
    logic [MANT_WIDTH-1:0] mant;
} fp_encoding_t;

typedef struct packed {
    fp_encoding_t u_result;
    logic [1:0] rs;
    logic round_en;
    logic invalid;
    logic [1:0] exp_cout;
} uround_res_t;

typedef struct packed {
    fp_encoding_t result;
    status_t flags;
} round_res_t;

typedef struct packed {
    logic sign;
    logic [EXP_WIDTH-1:0] exp;
    logic [2*MANT_WIDTH + 1:0] mant;
} fp_encoding_fma_t;

typedef struct packed {
    fp_encoding_fma_t u_result;
    logic [1:0] rs;
    logic round_en;
    logic invalid;
    logic [1:0] exp_cout;
} uround_res_fma_t;


