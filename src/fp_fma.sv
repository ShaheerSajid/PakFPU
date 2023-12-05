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
logic mul_urpr_s;
logic [2*MANT_WIDTH + 1:0] mul_urpr_mant;
logic [EXP_WIDTH + 1:0] mul_urpr_exp;

logic mul_invalid;

//compute
assign mul_urpr_s     = a_decoded.sign ^ b_decoded.sign;
assign mul_urpr_exp   = a_decoded.exp + b_decoded.exp;
assign mul_urpr_mant  = {a_info.is_normal, a_decoded.mant} * {b_info.is_normal, b_decoded.mant};

assign mul_invalid    = a_info.is_signalling | b_info.is_signalling | ((a_info.is_zero & b_info.is_inf) | (a_info.is_inf & b_info.is_zero));

////////////////////////////////////////////////////////
// Add/Sub 
////////////////////////////////////////////////////////
logic [EXP_WIDTH+1:0]exp_diff;
logic [EXP_WIDTH+1:0]exp_diff_offset;
logic [EXP_WIDTH+1:0]shamt;

logic add_urpr_s;
logic [3*MANT_WIDTH+4:0] add_urpr_mant;
logic [3*MANT_WIDTH+4:0] add_shift_mant;
logic [EXP_WIDTH+1:0] add_urpr_exp;

//precheck mul result

//compute
//FIXME
assign add_urpr_s = mul_urpr_s;
//calculate exponent
assign add_urpr_exp = (mul_urpr_exp > c_decoded.exp)? mul_urpr_exp : c_decoded.exp;
//calculate shift amount
assign exp_diff         = c_decoded.exp - mul_urpr_exp;
assign exp_diff_offset  = ($signed(exp_diff) >= $signed(MANT_WIDTH+4))? exp_diff - (MANT_WIDTH+4) : (MANT_WIDTH+4) - (-exp_diff);

assign shamt = ($signed(exp_diff) >= $signed(0))?  $signed(exp_diff_offset) > $signed(0)? exp_diff_offset : 'h0  
                                                :  $signed(exp_diff_offset) > $signed(3*MANT_WIDTH+5)? 3*MANT_WIDTH+5 : exp_diff_offset;

assign add_shift_mant = {c_info.is_normal, c_decoded.mant, {2*MANT_WIDTH+4{1'b0}}} >> shamt;
//calculate new mantissa (if different signs then subtract)
assign add_urpr_mant = add_shift_mant + mul_urpr_mant;

////////////////////////////////////////////////////////
// Normalize 
////////////////////////////////////////////////////////
logic [3*MANT_WIDTH+4:0] shifted_mant_norm;
logic [$clog2(FP_WIDTH)-1:0] shamt_norm;

lzc #(.WIDTH(3*MANT_WIDTH+5)) lzc_inst
(
    .a_i(add_urpr_mant),
    .cnt_o(shamt_norm),
    .zero_o()
);

assign shifted_mant_norm = add_urpr_mant << shamt_norm;
////////////////////////////////////////////////////////
// Sticky Genration 
////////////////////////////////////////////////////////
logic [EXP_WIDTH:0] stickyindex;
logic [MANT_WIDTH:0] sigC;
logic [MANT_WIDTH:0] compressed_mant;
logic stickybit;

assign sigC = {c_info.is_normal, c_decoded.mant};

genvar i;
generate
    for(i = 0; i <= MANT_WIDTH; i= i+1)
	begin : combine_sig
        assign compressed_mant[i] = |sigC[i:0];
	end
endgenerate
assign stickyindex = shamt - (GUARD_BITS + 1);

always_comb
    if($signed(stickyindex) < $signed(0))
        stickybit = 1'b0;
    else if($signed(stickyindex) > $signed(MANT_WIDTH))
        stickybit = compressed_mant[MANT_WIDTH];
    else
        stickybit = compressed_mant[stickyindex];
////////////////////////////////////////////////////////
// Output 
////////////////////////////////////////////////////////
logic sign_o;
logic [EXP_WIDTH-1:0] exp_o;
logic [MANT_WIDTH-1:0] mant_o;

assign sign_o = add_urpr_s;
assign mant_o = shifted_mant_norm[3*MANT_WIDTH+3 -: MANT_WIDTH];
assign exp_o  = add_urpr_exp - BIAS;

assign round_en_o = 1'b1;
assign rs_o = 'h0;
assign invalid_o = 'h0; 
assign exp_cout_o = 'h0;

assign result_o.sign = sign_o;
assign result_o.mant = mant_o;
assign result_o.exp = exp_o;

assign urnd_result_o.u_result =  result_o;
assign urnd_result_o.rs =  rs_o;
assign urnd_result_o.round_en =  round_en_o;
assign urnd_result_o.invalid =  invalid_o;
assign urnd_result_o.exp_cout =  exp_cout_o;
assign done_o = start_i;
endmodule