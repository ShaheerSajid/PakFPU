import fp_pkg::*;

module f2d
(
    a_i,
    rnd_result_o
);

localparam fp_format_e FP_FORMAT = FP64;
localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT);
localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT);
localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT);
`include "fp_defs.svh"
input [31:0] a_i;
output round_res_t rnd_result_o;

fp_encoding_t result_o;
status_t flags_o;

logic [10:0] exp_o;
logic [23:0] shifted_mant;
logic [10:0] a_exp_ext;
logic [10:0] shamt_ext;

fp32_encoding_t a_decoded;
assign a_decoded = a_i;

fp_info_t a_info;
assign a_info = fp32_info(a_i);


always_comb
begin
    flags_o = '0;
    if(a_info.is_signalling)
    begin
        result_o.sign = a_decoded.sign;
        result_o.mant = {1'b1, a_decoded.mant[21:0], 29'd0};
        result_o.exp = 11'd2047;
        flags_o.NV = 1'b1;
    end
    else if(a_info.is_inf | a_info.is_nan)
    begin
        result_o.sign = a_decoded.sign;
        result_o.mant = {a_decoded.mant,29'd0};
        result_o.exp = 11'd2047;
    end
    else if(a_info.is_zero)
    begin
        result_o.sign = a_decoded.sign;
        result_o.mant = 'd0;
        result_o.exp = 'd0;
    end
    else
    begin
        result_o.sign = a_decoded.sign;
        result_o.mant = {shifted_mant[22:0],29'd0};
        result_o.exp = exp_o;
    end
end

//if input denormal calculate left shift and decrement exponent
logic [4:0] shamt;

lzc #(.WIDTH(24)) lzc_inst
(
    .a_i({a_info.is_normal, a_decoded.mant}),
    .cnt_o(shamt),
    .zero_o()
);

assign shifted_mant = {a_info.is_normal, a_decoded.mant} << shamt;
assign a_exp_ext = {3'b0, a_decoded.exp};
assign shamt_ext = {6'b0, shamt};
assign exp_o = a_info.is_normal ? (a_exp_ext - 11'd127 + 11'd1023) : (a_exp_ext - 11'd126 + 11'd1023 - shamt_ext);

assign rnd_result_o.result = result_o;
assign rnd_result_o.flags = flags_o; 
endmodule
