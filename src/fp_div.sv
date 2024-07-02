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
    clk_i,
    reset_i,
    a_i,
    b_i,
    start_i,
    rnd_i,
    done_o,
    urnd_result_o,
    divide_by_zero,

);
`include "fp_class.sv"

input clk_i;
input reset_i;
input [FP_WIDTH-1:0] a_i;
input [FP_WIDTH-1:0] b_i;
input start_i;
input roundmode_e rnd_i;
output done_o;
output uround_res_t urnd_result_o;
output logic divide_by_zero;

fp_encoding_t result_o;
logic [1:0] rs_o;
logic round_en_o;
logic invalid_o;
logic [1:0] exp_cout_o;

logic urpr_s;
logic [MANT_WIDTH+1:0] urpr_mant;
logic [EXP_WIDTH+1:0] urpr_exp;
logic [EXP_WIDTH+1:0] shift_exp;

logic sign_o;
logic [EXP_WIDTH-1:0] exp_o;
logic [MANT_WIDTH-1:0] mant_o;

fp_encoding_t a_decoded;
fp_encoding_t b_decoded;

assign a_decoded = a_i;
assign b_decoded = b_i;

fp_info_t a_info;
fp_info_t b_info;

assign a_info = fp_info(a_i);
assign b_info = fp_info(b_i);

//precheck
always_comb
begin
  round_en_o = 1'b0;
  result_o = 'h0;
  divide_by_zero = 1'b0;

  if(a_info.is_nan)
    begin
        result_o.sign = a_decoded.sign;
        result_o.mant = {1'b1, a_decoded.mant[MANT_WIDTH-2:0]};
        result_o.exp = a_decoded.exp;
    end
    else if(b_info.is_nan)
    begin
        result_o.sign = b_decoded.sign;
        result_o.mant = {1'b1, b_decoded.mant[MANT_WIDTH-2:0]};
        result_o.exp = b_decoded.exp;
    end
    else if(a_info.is_inf)
        if(b_info.is_inf)
          result_o = R_IND;
        else
          result_o = {sign_o, INF};//{sign_o, 31'h7F800000};
    else if(a_info.is_normal || a_info.is_subnormal)
        if(b_info.is_inf)
          result_o = {sign_o, {FP_WIDTH-1{1'b0}}};
        else if(b_info.is_zero)
        begin
          divide_by_zero = 1'b1;
          result_o = {sign_o, INF};
        end
        else
        begin
            round_en_o = 1'b1;
            result_o.sign = sign_o;
            result_o.mant = mant_o;
            result_o.exp = exp_o;
        end
    else if(a_info.is_zero)
        if(b_info.is_zero)
            result_o = R_IND;
        else
            result_o = {sign_o, {FP_WIDTH-1{1'b0}}};
end

assign urpr_s = a_decoded.sign ^ b_decoded.sign;
always_comb 
  case({a_info.is_subnormal, b_info.is_subnormal})
  2'b00:  urpr_exp = (a_decoded.exp - b_decoded.exp) + (BIAS - 1);
  2'b01:  urpr_exp = (a_decoded.exp - b_decoded.exp) + (BIAS - 2);
  2'b10:  urpr_exp = (a_decoded.exp - b_decoded.exp) + (BIAS);
  2'b11:  urpr_exp = (a_decoded.exp - b_decoded.exp) + (BIAS - 1);
  endcase

//calculate shift
logic [$clog2(FP_WIDTH):0] shamt_a;
lzc #(.WIDTH(MANT_WIDTH+1)) lzc_inst_0
(
    .a_i({a_info.is_normal,a_decoded.mant}),
    .cnt_o(shamt_a),
    .zero_o()
);

logic [$clog2(FP_WIDTH):0] shamt_b;
lzc #(.WIDTH(MANT_WIDTH+1)) lzc_inst_1
(
    .a_i({b_info.is_normal,b_decoded.mant}),
    .cnt_o(shamt_b),
    .zero_o()
);

assign shift_exp = urpr_exp - shamt_a + shamt_b;

int_div #(.WIDTH(2*MANT_WIDTH+2)) int_div_inst
(
  .clk_i(clk_i),
  .reset_i(reset_i),
  .start_i(start_i),
  .n_i({a_info.is_normal, a_decoded.mant,{MANT_WIDTH+1{1'b0}}} << shamt_a), 
  .d_i({{MANT_WIDTH+1{1'b0}},b_info.is_normal, b_decoded.mant} << shamt_b),
  .q_o(urpr_mant), 
  .r_o(), 
  .valid_o(done_o)
);

assign sign_o = urpr_s;
assign {exp_cout_o, exp_o} = (urpr_mant[MANT_WIDTH+1])? shift_exp + 1: shift_exp;
assign mant_o = (urpr_mant[MANT_WIDTH+1])? urpr_mant >> 1 : urpr_mant;

//calculate RS
assign rs_o[1] = 1'b0;
assign rs_o[0] = 1'b0;

assign invalid_o = a_info.is_signalling | b_info.is_signalling | ((a_info.is_inf & b_info.is_inf) | (a_info.is_zero & b_info.is_zero));

assign urnd_result_o.u_result =  result_o;
assign urnd_result_o.rs =  rs_o;
assign urnd_result_o.round_en =  round_en_o;
assign urnd_result_o.invalid =  invalid_o;
assign urnd_result_o.exp_cout =  exp_cout_o;

endmodule