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
    output logic round_only,
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
Structs #(.FP_FORMAT(FP48))::uround_res_t add_result;
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

//denormalize logic
logic [EXP_WIDTH-1:0] uexp_o;
logic [2*MANT_WIDTH + 1:0] umant_o;
logic round_out;
logic [EXP_WIDTH-1:0] denorm_shift;
assign denorm_shift = $signed(0)-$signed({mul_result.exp_cout,mul_result.u_result.exp});
always_comb
begin
    uexp_o = {EXP_WIDTH{1'b0}};
    {umant_o, round_out} = {1'b1, norm_mul_mant[2*MANT_WIDTH + 1:0]} >> denorm_shift;
end

//new sticky logic
logic [EXP_WIDTH:0] stickyindex;
logic [2*MANT_WIDTH + 2:0] sigB;
logic [2*MANT_WIDTH + 2:0] compressed_mant;
logic new_stickybit;

assign sigB = {1'b1, norm_mul_mant[2*MANT_WIDTH + 1:0]};
genvar i;
generate
    for(i = 0; i <= (2*MANT_WIDTH+2); i= i+1)
	begin : combine_sig
        assign compressed_mant[i] = |sigB[i:0];
	end
endgenerate
assign stickyindex = denorm_shift - 1;

always_comb
    if($signed(stickyindex) < $signed(0))
        new_stickybit = 1'b0;
    else if($signed(stickyindex) > $signed(2*MANT_WIDTH+2))
        new_stickybit = compressed_mant[2*MANT_WIDTH+2];
    else
        new_stickybit = compressed_mant[stickyindex];

logic [1:0] mult_rs;
always_comb
    if($signed({mul_result.exp_cout,mul_result.u_result.exp}) <= $signed(0))
        mult_rs = {round_out , new_stickybit};
    else
        mult_rs = 2'b0;
logic mult_sticky_bit;
always_comb
    if($signed({mul_result.exp_cout,mul_result.u_result.exp}) <= $signed(0))
        mult_sticky_bit = round_out | new_stickybit;
    else
        mult_sticky_bit = 1'b0;

always_comb begin
    if ($signed({mul_result.exp_cout,mul_result.u_result.exp}) <= $signed(0) && !(a_info.is_zero || b_info.is_zero))
        joined_mul_result = {mul_result.u_result.sign,uexp_o,umant_o[2*MANT_WIDTH+1:1],umant_o[0] | mult_sticky_bit};
    else
        joined_mul_result = {mul_result.u_result.sign,mul_result.u_result.exp,norm_mul_mant};
end
//assign joined_mul_result = ($signed({mul_result.exp_cout,mul_result.u_result.exp}) <= $signed(0))? {mul_result.u_result.sign,uexp_o,umant_o[2*MANT_WIDTH+1:1],umant_o[0] | mult_sticky_bit} : {mul_result.u_result.sign,mul_result.u_result.exp,norm_mul_mant};
////////////////////////////////////////////////////////
// Add/Sub 
////////////////////////////////////////////////////////

fp_add  #(.FP_FORMAT(FP48)) fp_add_inst
(
    .a_i(joined_mul_result),
    .b_i({c_i, {MANT_WIDTH+2{1'b0}}}),
    .sub_i(1'b0),
    .rs_i(mult_rs),
    .rnd_i(rnd_i),
    .round_only(round_only),
    .urnd_result_o(add_result)
);

logic [MANT_WIDTH-1:0] mant_o;
assign mant_o = add_result.u_result.mant[2*MANT_WIDTH + 1 -: MANT_WIDTH];
////////////////////////////////////////////////////////
//  Output
////////////////////////////////////////////////////////
assign rs_o[1] = add_result.u_result.mant[MANT_WIDTH + 1];
assign rs_o[0] = (|add_result.u_result.mant[MANT_WIDTH:0]) | (|add_result.rs) | mult_sticky_bit;
assign invalid_o = a_info.is_signalling | b_info.is_signalling | ((a_decoded.sign ^ (sub_i ^ b_decoded.sign)) & a_info.is_inf & b_info.is_inf); 

assign round_en_o       = add_result.round_en;
assign result_o.sign    = add_result.u_result.sign;
assign result_o.mant    = mant_o;
assign result_o.exp     = add_result.u_result.exp;

assign urnd_result_o.u_result   =  result_o;
assign urnd_result_o.rs         =  rs_o;
assign urnd_result_o.round_en   =  round_en_o;
assign urnd_result_o.invalid    =  invalid_o;
assign urnd_result_o.exp_cout   =  add_result.exp_cout;

assign done_o = start_i;
endmodule