import fp_pkg::*;

module fp_div
#(
    parameter fp_format_e FP_FORMAT = FP32,

    localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT),
    localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT),
    localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT),

    localparam int unsigned BIAS = (2**(EXP_WIDTH-1)-1),
    localparam INF = {{EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}},
    localparam R_IND = {1'b1, {EXP_WIDTH{1'b1}}, 1'b1, {MANT_WIDTH-1{1'b0}}}
)
(
    input [FP_WIDTH-1:0] a_i,
    input [FP_WIDTH-1:0] b_i,
    input start_i,
    input roundmode_e rnd_i,
    output done_o,
    output Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t urnd_result_o

);

// subtract exponents
// divide mantissas


endmodule