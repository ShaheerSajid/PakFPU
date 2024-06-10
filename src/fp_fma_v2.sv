import fp_pkg::*;

module fp_fma
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
    input [FP_WIDTH-1:0] c_i,
    input start_i,
    input sub_i,
    input roundmode_e rnd_i,
    output done_o,
    output Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t urnd_result_o

);

Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t result_o;
logic [1:0] rs_o;
logic round_en_o;
logic invalid_o;
logic [1:0] exp_cout_o;

Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t a_decoded;
Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t b_decoded;
Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t c_decoded;

assign a_decoded = a_i;
assign b_decoded = b_i;
assign c_decoded = c_i;

fp_info_t a_info;
fp_info_t b_info;
fp_info_t c_info;

assign a_info = Functions #(.FP_FORMAT(FP_FORMAT))::fp_info(a_i);
assign b_info = Functions #(.FP_FORMAT(FP_FORMAT))::fp_info(b_i);
assign c_info = Functions #(.FP_FORMAT(FP_FORMAT))::fp_info(c_i);

////////////////////////////////////////////////////////
// Pre-check 
////////////////////////////////////////////////////////

////////////////////////////////////////////////////////
// Multiply 
////////////////////////////////////////////////////////
Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t mul_result;
localparam int unsigned FP_WIDTH_ADDER = fp_width(FP48);

logic [2*MANT_WIDTH + 1:0] norm_mul_mant;
logic [FP_WIDTH_ADDER-1:0] joined_mul_result;

fp_mul #(.FP_FORMAT(FP_FORMAT)) fp_mul_inst
(
    .a_i(a_i),
    .b_i(b_i),
    .norm_mant(norm_mul_mant),
    .urnd_result_o(mul_result)
);
assign joined_mul_result = {mul_result.u_result.sign,mul_result.u_result.exp,norm_mul_mant};
////////////////////////////////////////////////////////
// Add/Sub 
////////////////////////////////////////////////////////

fp_add  #(.FP_FORMAT(FP48)) fp_add_inst
(
    .a_i(joined_mul_result),
    .b_i({c_i, {MANT_WIDTH+2{1'b0}}}),
    .sub_i(1'b0),
    .rnd_i(rnd_i),
    .urnd_result_o(urnd_result_o)
);
////////////////////////////////////////////////////////
//  Output
////////////////////////////////////////////////////////
// assign rs_o = {shifted_mant_norm[GUARD_BITS - 1], |shifted_mant_norm[GUARD_BITS - 2:0] | stickybit | bitout};
// assign invalid_o = a_info.is_signalling | b_info.is_signalling | ((a_decoded.sign ^ (sub_i ^ b_decoded.sign)) & a_info.is_inf & b_info.is_inf); 

// assign round_en_o = 1'b1;
// assign result_o.sign = sign_o;
// assign result_o.mant = mant_o;
// assign result_o.exp = exp_o;

// assign urnd_result_o.u_result =  result_o;
// assign urnd_result_o.rs =  rs_o;
// assign urnd_result_o.round_en =  round_en_o;
// assign urnd_result_o.invalid =  invalid_o;
// assign urnd_result_o.exp_cout =  exp_cout_o;

// assign done_o = start_i;
endmodule