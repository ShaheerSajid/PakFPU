import fp_pkg::*;

module fp_sqrt
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
    start_i,
    rnd_i,
    done_o,
    urnd_result_o
);
`include "fp_class.sv"

input clk_i;
input reset_i;
input [FP_WIDTH-1:0] a_i;
input start_i;
input roundmode_e rnd_i;
output done_o;
output uround_res_t urnd_result_o;

fp_encoding_t result_o;
logic [1:0] rs_o;
logic round_en_o;
logic invalid_o;
logic [1:0] exp_cout_o;

logic urpr_s;
logic [MANT_WIDTH + GUARD_BITS:0] urpr_mant;
logic [EXP_WIDTH+1:0] urpr_exp;

logic sign_o;
logic [EXP_WIDTH-1:0] exp_o;
logic [MANT_WIDTH-1:0] mant_o;

fp_encoding_t a_decoded;

assign a_decoded = a_i;

fp_info_t a_info;

assign a_info = fp_info(a_i);

//precheck
always_comb
begin
    round_en_o = 1'b0;
    result_o = 'h0;

    if(a_info.is_nan)
    begin
        result_o.sign = a_decoded.sign;
        result_o.mant = {1'b1, a_decoded.mant[MANT_WIDTH-2:0]};
        result_o.exp = a_decoded.exp;
    end
    else if(a_info.is_minus)
        result_o = R_IND;
    else if(a_info.is_normal || a_info.is_subnormal)
        begin
            round_en_o = 1'b1;
            result_o.sign = sign_o;
            result_o.mant = mant_o;
            result_o.exp = exp_o;
        end
    else //+inf or zero
        result_o = a_decoded;
end

logic [MANT_WIDTH + GUARD_BITS: 0] mant_sqrt;
logic [MANT_WIDTH + GUARD_BITS + 1: 0] mant_rem;

int_sqrt #(.WIDTH(2*MANT_WIDTH+4+GUARD_BITS+1)) int_sqrt_inst
(
  .clk_i(clk_i),
  .reset_i(reset_i),
  .start_i(start_i),
  .n_i({2'b0,a_info.is_normal, a_decoded.mant,{MANT_WIDTH+1+GUARD_BITS+1{1'b0}}} << a_decoded.exp[0]), 
  .q_o(mant_sqrt),
  .r_o(mant_rem), 
  .valid_o(done_o)
);

assign urpr_s = a_decoded.sign;
assign urpr_exp = (a_decoded.exp >> 1) + ((BIAS - 1)/2) + a_decoded.exp[0];
assign urpr_mant = mant_sqrt;

//normalize
//added cout and sticky bit
logic [MANT_WIDTH + GUARD_BITS:0] shifted_mant_norm;
//calculate shift
logic [$clog2(FP_WIDTH)-1:0] shamt;
lzc #(.WIDTH(MANT_WIDTH+GUARD_BITS+1)) lzc_inst
(
    .a_i(urpr_mant),
    .cnt_o(shamt),
    .zero_o()
);

assign shifted_mant_norm = urpr_mant[MANT_WIDTH+GUARD_BITS]? urpr_mant[MANT_WIDTH+GUARD_BITS : 0] : urpr_mant << shamt;
assign sign_o = urpr_s;
assign exp_o = urpr_exp;
assign mant_o = shifted_mant_norm[MANT_WIDTH+GUARD_BITS-1 -: MANT_WIDTH];

//calculate RS
assign rs_o[1] = shifted_mant_norm[GUARD_BITS-1];
assign rs_o[0] = !(mant_rem[15:0] == 'hffff | ((mant_rem & 'h8007fff) == 'h8007fff));
assign invalid_o = a_info.is_signalling | (a_info.is_minus & ~a_info.is_quiet);
assign exp_cout_o = 'h0;

assign urnd_result_o.u_result =  result_o;
assign urnd_result_o.rs =  rs_o;
assign urnd_result_o.round_en =  round_en_o;
assign urnd_result_o.invalid =  invalid_o;
assign urnd_result_o.exp_cout =  exp_cout_o;


endmodule