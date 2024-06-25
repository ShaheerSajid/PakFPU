Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t adder_result_o;
logic [1:0] adder_rs_o;
logic adder_round_en_o;
logic [1:0] adder_exp_cout_o;

logic exp_eq, exp_lt;
logic mant_eq, mant_lt;
logic lt;

logic [EXP_WIDTH_ADDER-1:0]adder_exp_diff;
logic [MANT_WIDTH_ADDER + GUARD_BITS:0]adder_shifted_mant;
logic [MANT_WIDTH_ADDER:0]adder_bigger_mant;

logic adder_urpr_s;
logic [MANT_WIDTH_ADDER + GUARD_BITS + 2:0] adder_urpr_mant;
logic [EXP_WIDTH_ADDER-1:0] adder_urpr_exp;

logic adder_sign_o;
logic [EXP_WIDTH_ADDER-1:0] adder_exp_o;
logic [MANT_WIDTH_ADDER-1:0] adder_mant_o;

logic [EXP_WIDTH_ADDER:0] adder_stickyindex;
logic [MANT_WIDTH_ADDER:0] adder_sigB;
logic [MANT_WIDTH_ADDER:0] adder_compressed_mant;
logic adder_stickybit;

logic [EXP_WIDTH_ADDER+1:0] comb_exp;
logic inf_cond;
assign comb_exp = {exp_in, a_decoded.exp};

always_comb
begin
    adder_round_en_o = 1'b0;
	adder_result_o = 0;
    round_only = 1'b0;
    mul_ovf = 1'b0;
    mul_uf = 1'b0;
    if(a_info.is_nan)
    begin
        if(~round_en)
        begin
            adder_result_o.sign = a_decoded.sign;
            adder_result_o.mant = {1'b1, a_decoded.mant[MANT_WIDTH_ADDER-2:0]};
            adder_result_o.exp = a_decoded.exp;
        end
        else begin
        adder_round_en_o = 1'b1;
        adder_result_o.sign = adder_sign_o;
        adder_result_o.mant = adder_mant_o;
        adder_result_o.exp = adder_exp_o;
        end
    end
    if(c_info.is_nan)
    begin
        adder_result_o.sign = c_decoded.sign;
        adder_result_o.mant = {1'b1, c_decoded.mant[MANT_WIDTH_ADDER-2:0]};
        adder_result_o.exp = c_decoded.exp;
    end
    else if(a_info.is_inf)
    begin
        if(~round_en)
            adder_result_o = ((a_decoded.sign ^ (sub_i ^ c_decoded.sign)) & a_info.is_inf & c_info.is_inf)? R_IND : a_decoded;
        else begin
            adder_round_en_o = 1'b1;
            adder_result_o.sign = adder_sign_o;
            adder_result_o.mant = adder_mant_o;
            adder_result_o.exp = adder_exp_o;
        end
    end
    else if(inf_cond & ~c_info.is_inf)
    begin
        mul_ovf = 1'b1;
        adder_result_o = {a_decoded.sign, INF};
    end
    else if(a_info.is_normal || a_info.is_subnormal)
        if(c_info.is_inf)
        begin
            adder_result_o.sign = sub_i ^ c_decoded.sign;
            adder_result_o.mant = c_decoded.mant;
            adder_result_o.exp = c_decoded.exp;
        end
        else if(c_info.is_zero)
        begin
            adder_round_en_o = 1'b1;
            round_only = 1'b1;
            mul_uf = 1'b1;
            adder_result_o = a_decoded;
        end
        else
        begin
            if(a_decoded.exp == c_decoded.exp && a_decoded.mant == c_decoded.mant && (a_decoded.sign != (sub_i ^ c_decoded.sign)))
            begin
                adder_result_o.sign = (rnd_i == RDN);
                adder_result_o.mant = 0;
                adder_result_o.exp = 0;
            end
            else if(a_info.is_subnormal && c_info.is_subnormal)//both subnormal
            begin
                adder_round_en_o = 1'b1;
                round_only = 1'b1;
                mul_uf = 1'b1;
                adder_result_o.sign = adder_sign_o;
                adder_result_o.mant = adder_urpr_mant[MANT_WIDTH_ADDER + GUARD_BITS-:MANT_WIDTH_ADDER];
                adder_result_o.exp = adder_urpr_mant[MANT_WIDTH_ADDER + GUARD_BITS + 1] ? 'd1 : 'd0;
            end
            else//both normal or mixed
            begin
                adder_round_en_o = 1'b1;
                adder_result_o.sign = adder_sign_o;
                adder_result_o.mant = adder_mant_o;
                adder_result_o.exp = adder_exp_o;
            end
        end
    else if(a_info.is_zero)
    begin
        adder_result_o.sign = sub_i ^ c_decoded.sign;
        adder_result_o.mant = c_decoded.mant;
        adder_result_o.exp = c_decoded.exp;
        if(c_info.is_zero && ((sub_i ^ c_info.is_minus) ^ a_info.is_minus))
            adder_result_o.sign = (rnd_i == RDN);
    end
end

logic denormalA;
logic denormalB;

assign denormalA = (a_info.is_subnormal ^ c_info.is_subnormal) & a_info.is_subnormal;
assign denormalB = (a_info.is_subnormal ^ c_info.is_subnormal) & c_info.is_subnormal;

assign exp_eq = (a_decoded.exp == c_decoded.exp);
assign exp_lt = (a_decoded.exp < c_decoded.exp);

assign mant_eq = (a_decoded.mant == c_decoded.mant);
assign mant_lt = (a_decoded.mant < c_decoded.mant);

assign lt = exp_lt | (exp_eq & mant_lt);

assign adder_exp_diff = lt? (c_decoded.exp - a_decoded.exp) 
                    : (a_decoded.exp - c_decoded.exp);

assign adder_shifted_mant = lt? ({{a_info.is_normal | a_info.is_nan | a_info.is_inf, a_decoded.mant},{GUARD_BITS{1'b0}}} >> (denormalA ? adder_exp_diff - 1 : adder_exp_diff)) 
                        : ({{c_info.is_normal, c_decoded.mant},{GUARD_BITS{1'b0}}} >> (denormalB ? adder_exp_diff - 1 : adder_exp_diff));
assign adder_bigger_mant = lt? {c_info.is_normal, c_decoded.mant} : {a_info.is_normal | a_info.is_nan | a_info.is_inf, a_decoded.mant};

assign adder_urpr_s = lt? sub_i ^ c_decoded.sign : a_decoded.sign;
assign adder_urpr_mant = (a_decoded.sign ^ (sub_i ^ c_decoded.sign))? ({1'b0, adder_bigger_mant,{GUARD_BITS{1'b0}},1'b0} - {1'b0,adder_shifted_mant,adder_stickybit}) 
                                                            : ({1'b0, adder_bigger_mant,{GUARD_BITS{1'b0}},1'b0} + {1'b0,adder_shifted_mant,adder_stickybit});
assign adder_urpr_exp = lt? c_decoded.exp : a_decoded.exp;

//normalize
//added cout and sticky bit
logic [MANT_WIDTH_ADDER + GUARD_BITS + 1:0] adder_shifted_mant_norm;
//calculate shift

logic [$clog2(FP_WIDTH_ADDER)-1:0] adder_shamt;

lzc #(.WIDTH(MANT_WIDTH_ADDER+GUARD_BITS)) adder_lzc_inst
(
    .a_i(adder_urpr_mant[MANT_WIDTH_ADDER + GUARD_BITS + 1 : GUARD_BITS - 1]),
    .cnt_o(adder_shamt),
    .zero_o()
);

assign inf_cond  = ($signed(comb_exp) >  $signed(2**EXP_WIDTH_ADDER-1) );

logic bitout;
assign {adder_shifted_mant_norm, bitout} = adder_urpr_mant[MANT_WIDTH_ADDER + GUARD_BITS + 2]?  {adder_urpr_mant[MANT_WIDTH_ADDER + GUARD_BITS + 2:1],1'b0} >> 1'b1 
                                    : {adder_urpr_mant[MANT_WIDTH_ADDER + GUARD_BITS + 2:1],1'b0} << adder_shamt;

assign adder_sign_o = adder_urpr_s;
assign adder_mant_o = adder_shifted_mant_norm[MANT_WIDTH_ADDER + (GUARD_BITS - 1)-:MANT_WIDTH_ADDER];
assign {adder_exp_cout_o, adder_exp_o} = adder_urpr_mant[MANT_WIDTH_ADDER + GUARD_BITS + 2]? adder_urpr_exp + 1'b1 : adder_urpr_exp - adder_shamt;
//Sticky Logic
assign adder_sigB = lt? {a_info.is_normal, a_decoded.mant} : {c_info.is_normal, c_decoded.mant};

genvar i;
generate
    for(i = 0; i <= MANT_WIDTH_ADDER; i= i+1)
	begin : combine_sig
        assign adder_compressed_mant[i] = |adder_sigB[i:0];
	end
endgenerate
assign adder_stickyindex = adder_exp_diff - (GUARD_BITS + 1);

always_comb
    if($signed(adder_stickyindex) < $signed(0))
        adder_stickybit = 1'b0;
    else if($signed(adder_stickyindex) > $signed(MANT_WIDTH_ADDER))
        adder_stickybit = adder_compressed_mant[MANT_WIDTH_ADDER];
    else
        adder_stickybit = adder_compressed_mant[adder_stickyindex];
    

assign adder_rs_o = {adder_shifted_mant_norm[GUARD_BITS - 1], |adder_shifted_mant_norm[GUARD_BITS - 2:0] | adder_stickybit | bitout};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
