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

localparam int unsigned NUM_FP_FORMATS = 2; // change me to add formats
localparam int unsigned FP_FORMAT_BITS = $clog2(NUM_FP_FORMATS);

// FP formats
typedef enum logic [FP_FORMAT_BITS-1:0] {
FP32    = 'd0,
FP64    = 'd1
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
'{11, 52}, // IEEE binary64 (double)
'{8,  23} // IEEE binary32 (single)
// add new formats here
};

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

virtual class Structs 
#(  
    parameter fp_format_e FP_FORMAT = FP32
);

    localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT);
    localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT);
    typedef struct packed {
        logic sign;
        logic [EXP_WIDTH-1:0] exp;
        logic [MANT_WIDTH-1:0] mant;
    } fp_encoding_t;

    typedef struct packed {
      Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t u_result;
      logic [1:0] rs;
      logic round_en;
      logic invalid;
      logic [1:0] exp_cout;
    } uround_res_t;

    typedef struct packed {
      Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t result;
      status_t flags;
    } round_res_t;
endclass

//helper functions
virtual class Functions 
#(  
        parameter fp_format_e FP_FORMAT = FP32
);
    localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT);
    localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT);
    localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT);

    static function logic sign(logic [FP_WIDTH-1:0] val);
        return val[FP_WIDTH-1];
    endfunction
    static function logic [EXP_WIDTH-1:0] exp(logic [FP_WIDTH-1:0] val);
        return val[FP_WIDTH-2-:EXP_WIDTH];
    endfunction
    static function logic [MANT_WIDTH-1:0] mant(logic [FP_WIDTH-1:0] val);
        return val[FP_WIDTH-2-EXP_WIDTH:0];
    endfunction
    static function logic is_minus(logic [FP_WIDTH-1:0] val);
        return sign(val);
    endfunction
    static function logic is_normal(logic [FP_WIDTH-1:0] val);
        return (exp(val) >= 1) && (exp(val) <= (2**EXP_WIDTH-2));
    endfunction
    static function logic is_subnormal(logic [FP_WIDTH-1:0] val);
        return (exp(val) == 0) && (mant(val) != 0);
    endfunction
    static function logic is_zero(logic [FP_WIDTH-1:0] val);
        return val[FP_WIDTH-2:0] == 0;
    endfunction
    static function logic is_inf(logic [FP_WIDTH-1:0] val);
        return exp(val) == (2**EXP_WIDTH-1) && mant(val) == 0;
    endfunction
    static function logic is_nan(logic [FP_WIDTH-1:0] val);
        return exp(val) == (2**EXP_WIDTH-1) && mant(val) != 0;
    endfunction
    static function logic is_signalling(logic [FP_WIDTH-1:0] val);
        return exp(val) == (2**EXP_WIDTH-1) && mant(val) != 0 && !val[FP_WIDTH-2-EXP_WIDTH];
    endfunction
    static function logic is_quiet(logic [FP_WIDTH-1:0] val);
        return exp(val) == (exp(val) == (2**EXP_WIDTH-1) && val[FP_WIDTH-2-EXP_WIDTH]);
    endfunction
    static function logic is_canonical(logic [FP_WIDTH-1:0] val);
        return is_finite(val) | is_inf(val) | (exp(val) == (2**EXP_WIDTH-1) && val[FP_WIDTH-2-EXP_WIDTH]);
    endfunction
    static function logic is_finite(logic [FP_WIDTH-1:0] val);
        return is_zero(val) | is_subnormal(val) | is_normal(val);
    endfunction

    static function fp_info_t fp_info(logic [FP_WIDTH-1:0] val);
        fp_info_t info;
        info.is_minus       = is_minus(val);
        info.is_normal      = is_normal(val);
        info.is_subnormal   = is_subnormal(val);
        info.is_zero        = is_zero(val);
        info.is_inf         = is_inf(val);
        info.is_nan         = is_nan(val);
        info.is_signalling  = is_signalling(val);
        info.is_canonical   = is_canonical(val);
        info.is_finite      = is_finite(val);
        return info;
    endfunction
endclass

endpackage
