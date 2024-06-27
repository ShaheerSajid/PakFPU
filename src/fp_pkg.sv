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

localparam int unsigned NUM_FP_FORMATS = 3; // change me to add formats
localparam int unsigned FP_FORMAT_BITS = $clog2(NUM_FP_FORMATS);

// FP formats
typedef enum logic [FP_FORMAT_BITS-1:0] {
FP32    = 'd0,
FP48    = 'd1,
FP64    = 'd2
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
'{8,  48}, //internal FMA 
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

endpackage
