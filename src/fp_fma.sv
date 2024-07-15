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
    a_i,
    b_i,
    c_i,
    start_i,
    sub_i,
    rnd_i,
    done_o,
    round_only,
    mul_ovf,
    mul_uf,
    mul_uround_out,
    urnd_result_o
);
`include "fp_class.sv"

input [FP_WIDTH-1:0] a_i;
input [FP_WIDTH-1:0] b_i;
input [FP_WIDTH-1:0] c_i;
input start_i;
input sub_i;
input roundmode_e rnd_i;
output done_o;
output logic round_only;
output logic mul_ovf;
output logic mul_uf;
output logic mul_uround_out;
output uround_res_t urnd_result_o;


fp_encoding_t result_o;
logic [1:0] rs_o;
logic round_en_o;
logic invalid_o;
logic [1:0] exp_cout_o;

fp_encoding_t a_decoded;
fp_encoding_t b_decoded;
fp_encoding_t c_decoded;

assign a_decoded = a_i;
assign b_decoded = b_i;
assign c_decoded = c_i;

fp_info_t a_info;
fp_info_t b_info;
fp_info_t c_info;

assign a_info = fp_info(a_i);
assign b_info = fp_info(b_i);
assign c_info = fp_info(c_i);


////////////////////////////////////////////////////////
// Multiply 
////////////////////////////////////////////////////////
localparam int unsigned MANT_WIDTH_ADDER = 2*MANT_WIDTH + 2;
localparam int unsigned FP_WIDTH_ADDER = 1 + EXP_WIDTH + MANT_WIDTH_ADDER;
localparam INF_ADDER = {{EXP_WIDTH{1'b1}}, {MANT_WIDTH_ADDER{1'b0}}};
localparam R_IND_ADDER = {1'b1, {EXP_WIDTH{1'b1}}, 1'b1, {MANT_WIDTH_ADDER-1{1'b0}}};


fp_encoding_t mul_result;
logic mul_round_en;
logic [1:0] mul_exp_cout;

logic mul_urpr_s;
logic [2*MANT_WIDTH + 1:0] mul_urpr_mant;
logic [EXP_WIDTH + 1:0] mul_urpr_exp;

logic mul_sign;
logic [EXP_WIDTH-1:0] mul_exp;

logic [2*MANT_WIDTH + 1:0] mul_norm_mant;
logic [FP_WIDTH_ADDER-1:0] joined_mul_result;

//precheck
always_comb
begin
    mul_round_en = 1'b0;
	mul_result = 0;

    if(a_info.is_nan)
    begin
        mul_result.sign = a_decoded.sign;
        mul_result.exp = a_decoded.exp;
    end
    else if(b_info.is_nan)
    begin
        mul_result.sign = b_decoded.sign;
        mul_result.exp = b_decoded.exp;
    end
    else if(a_info.is_inf)
        if(b_info.is_zero)
            mul_result = R_IND;
        else
            mul_result = {mul_sign, INF};
    else if(a_info.is_normal || a_info.is_subnormal)
        if(b_info.is_inf)
            mul_result = {mul_sign, INF};
        else if(b_info.is_zero)
            mul_result = {mul_sign, {FP_WIDTH-1{1'b0}}};
        else
        begin
            mul_round_en = 1'b1;
            mul_result.sign = mul_sign;
            mul_result.exp = mul_exp;
        end
    else if(a_info.is_zero)
        if(b_info.is_inf)
            mul_result = R_IND;
        else
            mul_result = {mul_sign, {FP_WIDTH-1{1'b0}}};
end

assign mul_urpr_s = a_decoded.sign ^ b_decoded.sign;
assign mul_urpr_exp = (a_decoded.exp + b_decoded.exp) - ((a_info.is_subnormal | b_info.is_subnormal) ? BIAS-1 : BIAS );
assign mul_urpr_mant = {a_info.is_normal, a_decoded.mant} * {b_info.is_normal, b_decoded.mant};

//normalize
logic [2*MANT_WIDTH + 1:0] mul_shifted_mant_norm;
//calculate shift
logic [$clog2(FP_WIDTH):0] mul_shamt;
lzc #(.WIDTH(2*MANT_WIDTH+1)) mul_lzc_inst
(
    .a_i(mul_urpr_mant[2*MANT_WIDTH:0]),
    .cnt_o(mul_shamt),
    .zero_o()
);

assign mul_shifted_mant_norm = mul_urpr_mant << mul_shamt; 

assign mul_sign = mul_urpr_s;
assign {mul_exp_cout, mul_exp} = mul_urpr_mant[2*MANT_WIDTH + 1] ? mul_urpr_exp + 1'b1 : mul_urpr_exp - mul_shamt;
assign mul_norm_mant = mul_urpr_mant[2*MANT_WIDTH + 1] ? {mul_urpr_mant[2*MANT_WIDTH : 0],1'b0} : {mul_shifted_mant_norm[2*MANT_WIDTH - 1 : 0],2'b0};

//multiply denormalize logic
logic [EXP_WIDTH-1:0] mul_uexp;
logic [2*MANT_WIDTH + 1:0] mul_umant;
logic mul_round_out;
logic [EXP_WIDTH-1:0] mul_denorm_shift;
assign mul_denorm_shift = $signed(0)-$signed({mul_exp_cout,mul_result.exp});
always_comb
begin
    mul_uexp = {EXP_WIDTH{1'b0}};
    {mul_umant, mul_round_out} = {1'b1, mul_norm_mant[2*MANT_WIDTH + 1:0]} >> mul_denorm_shift;
end

//new sticky logic
logic [EXP_WIDTH:0] stickyindex;
logic [2*MANT_WIDTH + 2:0] sigB;
logic [2*MANT_WIDTH + 2:0] compressed_mant;
logic new_stickybit;

assign sigB = {1'b1, mul_norm_mant[2*MANT_WIDTH + 1:0]};
generate
    for(genvar i = 0; i <= (2*MANT_WIDTH+2); i= i+1)
	begin : combine_sig_mul
        assign compressed_mant[i] = |sigB[i:0];
	end
endgenerate
assign stickyindex = mul_denorm_shift - 1;

always_comb
    if($signed(stickyindex) < $signed(0))
        new_stickybit = 1'b0;
    else if($signed(stickyindex) > $signed(2*MANT_WIDTH+2))
        new_stickybit = compressed_mant[2*MANT_WIDTH+2];
    else
        new_stickybit = compressed_mant[stickyindex];

logic mult_sticky_bit;
always_comb
    if($signed({mul_exp_cout,mul_result.exp}) <= $signed(0))
        mult_sticky_bit = mul_round_out | new_stickybit;
    else
        mult_sticky_bit = 1'b0;

always_comb begin
    if ($signed({mul_exp_cout,mul_result.exp}) <= $signed(0) && !(a_info.is_zero || b_info.is_zero))
        joined_mul_result = {mul_result.sign,mul_uexp,mul_umant[2*MANT_WIDTH+1:1],mul_umant[0] | mult_sticky_bit};
    else
        joined_mul_result = {mul_result.sign,mul_result.exp,mul_norm_mant};
end
////////////////////////////////////////////////////////
// Add/Sub 
////////////////////////////////////////////////////////
logic mul_ovf_sig;
uround_res_fma_t add_result;

fp_fma_add_unit  #(.FP_FORMAT(FP48)) fp_add_inst
(
    .a_i(joined_mul_result),
    .b_i({c_i, {MANT_WIDTH+2{1'b0}}}),
    .sub_i(sub_i),
    .exp_in(mul_exp_cout),
    .round_en(mul_round_en),
    .rnd_i(rnd_i),
    .round_only(round_only),
    .mul_ovf(mul_ovf_sig),
    .mul_uf(mul_uf),
    .urnd_result_o(add_result)
);

logic [MANT_WIDTH-1:0] mant_o;
assign mant_o = add_result.u_result.mant[2*MANT_WIDTH + 1 -: MANT_WIDTH];
////////////////////////////////////////////////////////
//  Output
////////////////////////////////////////////////////////
assign rs_o[1] = add_result.u_result.mant[MANT_WIDTH + 1];
assign rs_o[0] = (|add_result.u_result.mant[MANT_WIDTH:0]) | (|add_result.rs) | mult_sticky_bit;
assign invalid_o = a_info.is_signalling | b_info.is_signalling | c_info.is_signalling | 
                    ((a_info.is_inf & b_info.is_zero) | (a_info.is_zero & b_info.is_inf)) |
                    (!a_info.is_nan && !b_info.is_nan && c_info.is_inf & ((mul_result.sign ^ (sub_i ^ c_decoded.sign)) & (a_info.is_inf | b_info.is_inf)));

always_comb
    case (rnd_i)
        RNE, RMM :  mul_uround_out = ~add_result.u_result.mant[MANT_WIDTH];
        default:    mul_uround_out = ~(|add_result.rs) & (rs_o == 2'b01 | rs_o == 2'b10);
    endcase


////////////////////////////////////////////////////////
// Pre-check 
////////////////////////////////////////////////////////
always_comb
begin
    round_en_o = 1'b0;
	result_o = 0;
    mul_ovf = 1'b0;

    if((a_info.is_inf & b_info.is_zero) | (a_info.is_zero & b_info.is_inf))
        result_o = R_IND;
    else if(a_info.is_nan)
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
    else if(c_info.is_nan)
    begin
        result_o.sign = c_decoded.sign;
        result_o.mant = {1'b1, c_decoded.mant[MANT_WIDTH-2:0]};
        result_o.exp = c_decoded.exp;
    end
    else if(c_info.is_inf)
        // This should be calculated as finite inputs can result in infinite output due to ovf
        // Maybe you already checked that in adder
        result_o = ((mul_result.sign ^ (sub_i ^ c_decoded.sign)) & (a_info.is_inf | b_info.is_inf))? R_IND : {sub_i ^ c_decoded.sign,c_decoded.exp,c_decoded.mant} ;
    else
    begin
        round_en_o       = add_result.round_en;
        result_o.sign    = add_result.u_result.sign;
        result_o.mant    = mant_o;
        result_o.exp     = add_result.u_result.exp;
        mul_ovf          = mul_ovf_sig & ~invalid_o;
    end
end

assign urnd_result_o.u_result   =  result_o;
assign urnd_result_o.rs         =  rs_o;
assign urnd_result_o.round_en   =  round_en_o;
assign urnd_result_o.invalid    =  invalid_o;
assign urnd_result_o.exp_cout   =  add_result.exp_cout;

assign done_o = start_i;
endmodule




module fp_fma_add_unit
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
    a_i,
    b_i,
    start_i,
    sub_i,
    exp_in,
    round_en,
    rnd_i,
    done_o,
    round_only,
    mul_ovf,
    mul_uf,
    urnd_result_o

);
`include "fp_class.sv"

input [FP_WIDTH-1:0] a_i;
input [FP_WIDTH-1:0] b_i;
input start_i;
input sub_i;
input [1:0]exp_in;
input round_en;
input roundmode_e rnd_i;
output done_o;
output logic round_only;
output logic mul_ovf;
output logic mul_uf;
output uround_res_t urnd_result_o;

fp_encoding_t result_o;
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

fp_encoding_t a_decoded;
fp_encoding_t b_decoded;

logic [EXP_WIDTH:0] stickyindex;
logic [MANT_WIDTH:0] sigB;
logic [MANT_WIDTH:0] compressed_mant;
logic stickybit;

assign a_decoded = a_i;
assign b_decoded = b_i;

fp_info_t a_info;
fp_info_t b_info;

assign a_info = fp_info(a_i);
assign b_info = fp_info(b_i);

logic [EXP_WIDTH+1:0] comb_exp;
logic inf_cond;
assign comb_exp = {exp_in, a_decoded.exp};

always_comb
begin
    round_en_o = 1'b0;
	result_o = 0;
    round_only = 1'b0;
    mul_ovf = 1'b0;
    mul_uf = 1'b0;
    if(a_info.is_nan)
    begin
        if(~round_en)
        begin
            result_o.sign = a_decoded.sign;
            result_o.mant = {1'b1, a_decoded.mant[MANT_WIDTH-2:0]};
            result_o.exp = a_decoded.exp;
        end
        else begin
        round_en_o = 1'b1;
        result_o.sign = sign_o;
        result_o.mant = mant_o;
        result_o.exp = exp_o;
        end
    end
    if(b_info.is_nan)
    begin
        result_o.sign = b_decoded.sign;
        result_o.mant = {1'b1, b_decoded.mant[MANT_WIDTH-2:0]};
        result_o.exp = b_decoded.exp;
    end
    else if(a_info.is_inf)
    begin
        if(~round_en)
            result_o = ((a_decoded.sign ^ (sub_i ^ b_decoded.sign)) & a_info.is_inf & b_info.is_inf)? R_IND : a_decoded;
        else begin
            round_en_o = 1'b1;
            result_o.sign = sign_o;
            result_o.mant = mant_o;
            result_o.exp = exp_o;
        end
    end
    else if(inf_cond & ~b_info.is_inf)
    begin
        mul_ovf = 1'b1;
        result_o = {a_decoded.sign, INF};
    end
    else if(a_info.is_normal || a_info.is_subnormal)
        if(b_info.is_inf)
        begin
            result_o.sign = sub_i ^ b_decoded.sign;
            result_o.mant = b_decoded.mant;
            result_o.exp = b_decoded.exp;
        end
        else if(b_info.is_zero)
        begin
            round_en_o = 1'b1;
            round_only = 1'b1;
            mul_uf = 1'b1;
            result_o = a_decoded;
        end
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
                round_en_o = 1'b1;
                round_only = 1'b1;
                mul_uf = 1'b1;
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

assign shifted_mant = lt? ({{a_info.is_normal | a_info.is_nan | a_info.is_inf, a_decoded.mant},{GUARD_BITS{1'b0}}} >> (denormalA ? exp_diff - 1 : exp_diff)) 
                        : ({{b_info.is_normal, b_decoded.mant},{GUARD_BITS{1'b0}}} >> (denormalB ? exp_diff - 1 : exp_diff));
assign bigger_mant = lt? {b_info.is_normal, b_decoded.mant} : {a_info.is_normal | a_info.is_nan | a_info.is_inf, a_decoded.mant};

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

assign inf_cond  = ($signed(comb_exp) >  $signed(2**EXP_WIDTH-1) );

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