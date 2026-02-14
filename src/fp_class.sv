
//helper functions
// virtual class Functions 
// #(  
//         parameter fp_format_e FP_FORMAT = FP32
// );
//     localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT);
//     localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT);
//     localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT);

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
// endclass

// virtual class Structs 
// #(  
//     parameter fp_format_e FP_FORMAT = FP32
// );

//     localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT);
//     localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT);
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
// endclass

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

// Fixed-width encodings for mixed-format conversion modules.
typedef struct packed {
    logic sign;
    logic [7:0] exp;
    logic [22:0] mant;
} fp32_encoding_t;

typedef struct packed {
    logic sign;
    logic [10:0] exp;
    logic [51:0] mant;
} fp64_encoding_t;

function automatic fp_info_t fp32_info(input logic [31:0] val);
    fp_info_t info;
    fp32_encoding_t decoded;
    begin
        decoded = val;
        info = '0;
        info.is_minus       = decoded.sign;
        info.is_normal      = (decoded.exp >= 8'd1) && (decoded.exp <= 8'd254);
        info.is_subnormal   = (decoded.exp == 8'd0) && (decoded.mant != '0);
        info.is_zero        = (decoded.exp == '0) && (decoded.mant == '0);
        info.is_inf         = (decoded.exp == 8'hff) && (decoded.mant == '0);
        info.is_nan         = (decoded.exp == 8'hff) && (decoded.mant != '0);
        info.is_signalling  = info.is_nan && !decoded.mant[22];
        info.is_quiet       = info.is_nan && decoded.mant[22];
        info.is_finite      = info.is_zero | info.is_subnormal | info.is_normal;
        info.is_canonical   = info.is_finite | info.is_inf | info.is_quiet;
        return info;
    end
endfunction

function automatic fp_info_t fp64_info(input logic [63:0] val);
    fp_info_t info;
    fp64_encoding_t decoded;
    begin
        decoded = val;
        info = '0;
        info.is_minus       = decoded.sign;
        info.is_normal      = (decoded.exp >= 11'd1) && (decoded.exp <= 11'd2046);
        info.is_subnormal   = (decoded.exp == 11'd0) && (decoded.mant != '0);
        info.is_zero        = (decoded.exp == '0) && (decoded.mant == '0);
        info.is_inf         = (decoded.exp == 11'h7ff) && (decoded.mant == '0);
        info.is_nan         = (decoded.exp == 11'h7ff) && (decoded.mant != '0);
        info.is_signalling  = info.is_nan && !decoded.mant[51];
        info.is_quiet       = info.is_nan && decoded.mant[51];
        info.is_finite      = info.is_zero | info.is_subnormal | info.is_normal;
        info.is_canonical   = info.is_finite | info.is_inf | info.is_quiet;
        return info;
    end
endfunction
