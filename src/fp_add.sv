import fp_pkg::*;

module fp_add
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


logic exp_eq, exp_lt;
logic mant_eq, mant_lt;
logic lt;

logic [EXP_WIDTH-1:0]exp_diff;
logic [MANT_WIDTH + GUARD_BITS:0]shifted_mant;
logic [MANT_WIDTH:0]bigger_mant;

logic urpr_s;
logic [MANT_WIDTH + GUARD_BITS + 2:0] urpr_mant;
logic [EXP_WIDTH-1:0] urpr_exp;

logic sign_o;
logic [EXP_WIDTH-1:0] exp_o;
logic [MANT_WIDTH-1:0] mant_o;

Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t a_decoded;
Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t b_decoded;

logic [EXP_WIDTH:0] stickyindex;
logic [MANT_WIDTH:0] sigB;
logic [MANT_WIDTH:0] compressed_mant;
logic stickybit;

assign a_decoded = a_i;
assign b_decoded = b_i;

fp_info_t a_info;
fp_info_t b_info;

assign a_info = Functions #(.FP_FORMAT(FP_FORMAT))::fp_info(a_i);
assign b_info = Functions #(.FP_FORMAT(FP_FORMAT))::fp_info(b_i);

/*
Input sanity and exception check
1) any NANs
2) other invalid
3) any denorm
4) any infinity
*/
always_comb
begin
    round_en_o = 1'b0;
	result_o = 0;
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
        result_o = ((a_decoded.sign ^ (sub_i ^ b_decoded.sign)) & a_info.is_inf & b_info.is_inf)? R_IND : a_decoded;
    else if(a_info.is_normal || a_info.is_subnormal)
        if(b_info.is_inf)
        begin
            result_o.sign = sub_i ^ b_decoded.sign;
            result_o.mant = b_decoded.mant;
            result_o.exp = b_decoded.exp;
        end
        else if(b_info.is_zero)
            result_o = a_decoded;
        else
        begin
            if(a_decoded.exp == b_decoded.exp && a_decoded.mant == b_decoded.mant && (a_decoded.sign != (sub_i ^ b_decoded.sign)))
            begin
                result_o.sign = (rnd_i == RDN);
                result_o.mant = 0;
                result_o.exp = 0;
            end
            else if(a_info.is_subnormal && b_info.is_subnormal)//both subnormal
            begin
                result_o.sign = sign_o;
                result_o.mant = urpr_mant[MANT_WIDTH + GUARD_BITS-:MANT_WIDTH];
                result_o.exp = urpr_mant[MANT_WIDTH + GUARD_BITS + 1] ? 'd1 : 'd0;
            end
            else//both normal or mixed
            begin
                round_en_o = 1'b1;
                result_o.sign = sign_o;
                result_o.mant = mant_o;
                result_o.exp = exp_o;
            end
        end
    else if(a_info.is_zero)
    begin
        result_o.sign = sub_i ^ b_decoded.sign;
        result_o.mant = b_decoded.mant;
        result_o.exp = b_decoded.exp;
        if(b_info.is_zero && ((sub_i ^ b_info.is_minus) ^ a_info.is_minus))
            result_o.sign = (rnd_i == RDN);
    end
end

logic denormalA;
logic denormalB;

assign denormalA = (a_info.is_subnormal ^ b_info.is_subnormal) & a_info.is_subnormal;
assign denormalB = (a_info.is_subnormal ^ b_info.is_subnormal) & b_info.is_subnormal;

assign exp_eq = (a_decoded.exp == b_decoded.exp);
assign exp_lt = (a_decoded.exp < b_decoded.exp);

assign mant_eq = (a_decoded.mant == b_decoded.mant);
assign mant_lt = (a_decoded.mant < b_decoded.mant);

assign lt = exp_lt | (exp_eq & mant_lt);

assign exp_diff = lt? (b_decoded.exp - a_decoded.exp) 
                    : (a_decoded.exp - b_decoded.exp);

assign shifted_mant = lt? ({{a_info.is_normal, a_decoded.mant},{GUARD_BITS{1'b0}}} >> (denormalA ? exp_diff - 1 : exp_diff)) 
                        : ({{b_info.is_normal, b_decoded.mant},{GUARD_BITS{1'b0}}} >> (denormalB ? exp_diff - 1 : exp_diff));
assign bigger_mant = lt? {b_info.is_normal, b_decoded.mant} : {a_info.is_normal, a_decoded.mant};

assign urpr_s = lt? sub_i ^ b_decoded.sign : a_decoded.sign;
assign urpr_mant = (a_decoded.sign ^ (sub_i ^ b_decoded.sign))? ({1'b0, bigger_mant,{GUARD_BITS{1'b0}},1'b0} - {1'b0,shifted_mant,stickybit}) 
                                                            : ({1'b0, bigger_mant,{GUARD_BITS{1'b0}},1'b0} + {1'b0,shifted_mant,stickybit});
assign urpr_exp = lt? b_decoded.exp : a_decoded.exp;

//normalize
//added cout and sticky bit
logic [MANT_WIDTH + GUARD_BITS + 1:0] shifted_mant_norm;
//calculate shift

logic [$clog2(FP_WIDTH)-1:0] shamt;

lzc #(.WIDTH(MANT_WIDTH+GUARD_BITS)) lzc_inst
(
    .a_i(urpr_mant[MANT_WIDTH + GUARD_BITS + 1 : GUARD_BITS - 1]),
    .cnt_o(shamt),
    .zero_o()
);

logic bitout;
assign {shifted_mant_norm, bitout} = urpr_mant[MANT_WIDTH + GUARD_BITS + 2]?  {urpr_mant[MANT_WIDTH + GUARD_BITS + 2:1],1'b0} >> 1'b1 
                                    : {urpr_mant[MANT_WIDTH + GUARD_BITS + 2:1],1'b0} << shamt;

assign sign_o = urpr_s;
assign mant_o = shifted_mant_norm[MANT_WIDTH + (GUARD_BITS - 1)-:MANT_WIDTH];
assign {exp_cout_o, exp_o} = urpr_mant[MANT_WIDTH + GUARD_BITS + 2]? urpr_exp + 1'b1 : urpr_exp - shamt;
//Sticky Logic
assign sigB = lt? {a_info.is_normal, a_decoded.mant} : {b_info.is_normal, b_decoded.mant};

genvar i;
generate
    for(i = 0; i <= MANT_WIDTH; i= i+1)
	begin : combine_sig
        assign compressed_mant[i] = |sigB[i:0];
	end
endgenerate
assign stickyindex = exp_diff - (GUARD_BITS + 1);

always_comb
    if($signed(stickyindex) < $signed(0))
        stickybit = 1'b0;
    else if($signed(stickyindex) > $signed(MANT_WIDTH))
        stickybit = compressed_mant[MANT_WIDTH];
    else
        stickybit = compressed_mant[stickyindex];
    

assign rs_o = {shifted_mant_norm[GUARD_BITS - 1], |shifted_mant_norm[GUARD_BITS - 2:0] | stickybit | bitout};
assign invalid_o = a_info.is_signalling | b_info.is_signalling | ((a_decoded.sign ^ (sub_i ^ b_decoded.sign)) & a_info.is_inf & b_info.is_inf); 


assign urnd_result_o.u_result =  result_o;
assign urnd_result_o.rs =  rs_o;
assign urnd_result_o.round_en =  round_en_o;
assign urnd_result_o.invalid =  invalid_o;
assign urnd_result_o.exp_cout =  exp_cout_o;

assign done_o = start_i;

endmodule