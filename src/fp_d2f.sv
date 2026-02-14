import fp_pkg::*;

module d2f
(
    a_i,
    urnd_result_o
);

localparam fp_format_e FP_FORMAT = FP32;
localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT);
localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT);
localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT);
`include "fp_class.sv"
input [63:0] a_i;
output uround_res_t urnd_result_o;

fp_encoding_t result_o;
logic [1:0] rs_o;
logic round_en_o;
logic invalid_o;
logic [1:0] exp_cout_o;

logic urpr_s;
logic [23 + 2:0] urpr_mant;
logic [11:0] urpr_exp;

logic sign_o;
logic [7:0] exp_o;
logic [22:0] mant_o;

fp64_encoding_t a_decoded;
assign a_decoded = a_i;

fp_info_t a_info;
assign a_info = fp64_info(a_i);


always_comb
begin
    round_en_o = 1'b0;
    invalid_o = 1'b0;

    if(a_info.is_signalling)
    begin
        result_o.sign = a_decoded.sign;
        result_o.mant = {1'b1, a_decoded.mant[50-:22]};
        result_o.exp = 8'd255;
        invalid_o = 1'b1;
    end
    else if(a_info.is_inf | a_info.is_nan)
    begin
        result_o.sign = a_decoded.sign;
        result_o.mant = a_decoded.mant[51-:23];
        result_o.exp = 8'd255;
    end
    else if(a_info.is_zero)
    begin
        result_o.sign = a_decoded.sign;
        result_o.mant = 'd0;
        result_o.exp = 'd0;
    end
    else
    begin
        result_o.sign = sign_o;
        result_o.mant = mant_o;
        result_o.exp = exp_o;
        round_en_o = 1'b1;
    end
end


//calculate urpr
assign urpr_s = a_decoded.sign;
assign urpr_mant = {a_info.is_normal, a_decoded.mant[51-:23], a_decoded.mant[28], |a_decoded.mant[27:0]};
assign urpr_exp = {1'b0, a_decoded.exp} + 12'd127 - 12'd1023;

assign exp_cout_o = {urpr_exp[11] , |urpr_exp[10:8]};

assign sign_o = urpr_s;
assign mant_o = urpr_mant[24-:23];
assign exp_o = ($signed(urpr_exp) < -12'sd127) ? 8'd1 : urpr_exp[7:0];

assign rs_o = urpr_mant[1:0];

assign urnd_result_o.u_result =  result_o;
assign urnd_result_o.rs =  rs_o;
assign urnd_result_o.round_en =  round_en_o;
assign urnd_result_o.invalid =  invalid_o;
assign urnd_result_o.exp_cout =  exp_cout_o;

endmodule
