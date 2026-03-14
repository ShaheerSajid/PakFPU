package fp_pkg;


localparam int unsigned GUARD_BITS = 3;

// Rounding modes
typedef enum logic [2:0] {
    RNE = 3'b000,
    RTZ = 3'b001,
    RDN = 3'b010,
    RUP = 3'b011,
    RMM = 3'b100,
    DYN = 3'b111
} roundmode_e;

// Status flags
typedef struct packed {
    logic NV; // Invalid
    logic DZ; // Divide by zero
    logic OF; // Overflow
    logic UF; // Underflow
    logic NX; // Inexact
} status_t;

// Information about a floating point value
typedef struct packed {
    logic is_minus;      // is the value negative
    logic is_finite;     // is the value finite
    logic is_normal;     // is the value normal
    logic is_subnormal;  // is the value subnormal
    logic is_zero;       // is the value zero
    logic is_inf;        // is the value infinity
    logic is_nan;        // is the value NaN
    logic is_signalling; // is the value a signalling NaN
    logic is_canonical;  // is the value canonical
    logic is_boxed;      // is boxed
    logic is_quiet;      // is quiet
} fp_info_t;

// Classification mask
typedef enum logic [9:0] {
    NEGINF     = 10'b00_0000_0001,
    NEGNORM    = 10'b00_0000_0010,
    NEGSUBNORM = 10'b00_0000_0100,
    NEGZERO    = 10'b00_0000_1000,
    POSZERO    = 10'b00_0001_0000,
    POSSUBNORM = 10'b00_0010_0000,
    POSNORM    = 10'b00_0100_0000,
    POSINF     = 10'b00_1000_0000,
    SNAN       = 10'b01_0000_0000,
    QNAN       = 10'b10_0000_0000
} classmask_e;

//operations
//floating
typedef enum logic[3:0] {
	FADD,
	FMUL,
	FDIV,
	I2F,
	F2I,
	F2F,
	FCMP,
	FCLASS,
	FMIN,
	FMAX,
	FSGNJ,
	FMADD,
	NO_FP_OP
} float_op_e;


// Encoding for a format
typedef struct packed {
    int unsigned exp_bits;
    int unsigned man_bits;
} fp_widths_t;

localparam int unsigned NUM_FP_FORMATS = 4; // change me to add formats
localparam int unsigned FP_FORMAT_BITS = $clog2(NUM_FP_FORMATS);

// FP formats
typedef enum logic [FP_FORMAT_BITS-1:0] {
FP32    = 2'd0,
FP48    = 2'd1,  // internal FMA format for FP32 (exp=8,  mant=48  = 2×23+2)
FP64    = 2'd2,
FP118   = 2'd3   // internal FMA format for FP64 (exp=11, mant=106 = 2×52+2)
// add new formats here
} fp_format_e;

localparam int unsigned NUM_INT_FORMATS = 2; // change me to add formats
localparam int unsigned INT_FORMAT_BITS = $clog2(NUM_INT_FORMATS);

// Int formats
typedef enum logic [INT_FORMAT_BITS-1:0] {
    INT32,
    INT64
    // add new formats here
} int_format_e;

// Encodings for supported FP formats
localparam fp_widths_t [NUM_FP_FORMATS-1:0] FP_ENCODINGS  = '{
'{11, 106}, // internal FMA format for FP64
'{11, 52},  // IEEE binary64 (double)
'{8,  48},  // internal FMA format for FP32
'{8,  23}   // IEEE binary32 (single)
// add new formats here
};

// Fixed-width encodings for FP32/FP64, used by cross-format conversion
// modules (f2d, d2f) and any code that needs format-specific types without
// a parameterized module context.
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

function automatic int maximum(int a, int b);
    return (a > b) ? a : b;
  endfunction

function automatic int unsigned int_width(int_format_e ifmt);
    unique case (ifmt)
        INT32: return 32;
        INT64: return 64;
        default: return 32;
    endcase
endfunction

function automatic int unsigned fp_width(fp_format_e fmt);
    return FP_ENCODINGS[fmt].exp_bits + FP_ENCODINGS[fmt].man_bits + 1;
endfunction

function automatic int unsigned exp_bits(fp_format_e fmt);
    return FP_ENCODINGS[fmt].exp_bits;
endfunction

  // Returns the number of mantissa bits for a format
function automatic int unsigned man_bits(fp_format_e fmt);
    return FP_ENCODINGS[fmt].man_bits;
endfunction

// Returns the internal FMA intermediate format for a given user-facing format.
// The internal format shares the same exponent width but carries 2*MANT_WIDTH+2
// mantissa bits to hold the full multiply result before the add stage.
function automatic int unsigned fma_format(fp_format_e fmt);
    case (fmt)
        FP64:    return int'(FP118);
        default: return int'(FP48);
    endcase
endfunction

endpackage
