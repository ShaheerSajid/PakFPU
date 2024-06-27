import fp_pkg::*;

module f2d
(
    a_i,
    rnd_result_o
);
`include "fp_class.sv"
input [31:0] a_i;
output Structs #(.FP_FORMAT(FP64))::round_res_t rnd_result_o;

Structs #(.FP_FORMAT(FP64))::fp_encoding_t result_o;
status_t flags_o;

logic [10:0] exp_o;
logic [23:0] shifted_mant;


Structs #(.FP_FORMAT(FP32))::fp_encoding_t a_decoded;
assign a_decoded = a_i;

fp_info_t a_info;
assign a_info = Functions #(.FP_FORMAT(FP32))::fp_info(a_i);


always_comb
begin
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
        flags_o.NV = 1'b0;
    end
    else if(a_info.is_zero)
    begin
        result_o.sign = a_decoded.sign;
        result_o.mant = 'd0;
        result_o.exp = 'd0;
        flags_o.NV = 1'b0;
    end
    else
    begin
        result_o.sign = a_decoded.sign;
        result_o.mant = {shifted_mant,29'd0};
        result_o.exp = exp_o;
        flags_o.NV = 1'b0;
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
assign exp_o = a_info.is_normal? a_decoded.exp - 8'd127 + 11'd1023 : a_decoded.exp - 8'd126 + 11'd1023 - shamt;

assign rnd_result_o.result = result_o;
assign rnd_result_o.flags = flags_o; 
endmodule