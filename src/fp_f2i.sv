import fp_pkg::*;

module fp_f2i
#(
    parameter fp_format_e FP_FORMAT = FP32,
    parameter int_format_e INT_FORMAT = INT32,

    localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT),
    localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT),
    localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT),
    localparam int unsigned INT_WIDTH = int_width(INT_FORMAT),
    localparam int unsigned BIAS = (2**(EXP_WIDTH-1)-1)
)
(
    input [FP_WIDTH-1:0] a_i,
    input signed_i,
    input start_i,
    input roundmode_e rnd_i,
    output logic [INT_WIDTH-1:0] result_o,
    output status_t flags_o,
    output done_o
);
`include "fp_class.sv"
logic [MANT_WIDTH+INT_WIDTH-1:0] pre_round_mant;
logic [INT_WIDTH:0] round_int;
logic [1:0] rs;
logic [MANT_WIDTH:0] sigB;
logic stickybit;
logic round_up;
logic  [EXP_WIDTH-1:0] shamt;

fp_encoding_t a_decoded;
assign a_decoded = a_i;

fp_info_t a_info;
assign a_info = fp_info(a_i);


//sanity check
always_comb
begin
    result_o = 0;
    //unsigned conversion
    if(~signed_i)
    begin
        if(a_info.is_nan || (a_info.is_inf & ~a_info.is_minus))
        begin
            result_o =  2**(INT_WIDTH) - 1;
            flags_o.NV = 1'b1;
        end
        else if(a_info.is_zero)  
        begin       
            result_o =  0;   
            flags_o.NV = 1'b0;
        end
        else
            if(a_info.is_minus)
                case(rnd_i)
                    RDN:        begin
                                    result_o = 2**(INT_WIDTH) - 1;
                                    flags_o.NV = 1'b1;
                                end
                    RUP, RTZ:   begin   
                                    result_o = (a_decoded.exp >= BIAS)? 2**(INT_WIDTH) - 1 : 0;
                                    flags_o.NV = (a_decoded.exp >= BIAS);
                                end
                    RNE, RMM:   begin        
                                    result_o = (a_decoded.exp >= BIAS | round_up)? 2**(INT_WIDTH) - 1 : 0;
                                    flags_o.NV = (a_decoded.exp >= BIAS | round_up);
                                end
                    default:    begin
                                    result_o = 0;
                                    flags_o.NV = 1'b0;
                                end
                endcase
            else
                begin
                    result_o = ((a_decoded.exp >= BIAS && shamt >= INT_WIDTH) | round_int[INT_WIDTH])? 2**(INT_WIDTH) - 1 : round_int;
                    flags_o.NV = (a_decoded.exp >= BIAS && shamt >= INT_WIDTH) | round_int[INT_WIDTH];
                end
    end
    else
    begin
        if(a_info.is_nan || (a_info.is_inf & ~a_info.is_minus))
        begin
            result_o =  2**(INT_WIDTH-1);
            flags_o.NV = 1'b1;
        end
        else if(a_info.is_zero)  
        begin       
            result_o =  0;
            flags_o.NV = 1'b0;
        end 
        else
            if(a_info.is_minus)
            begin
                result_o = (a_decoded.exp >= BIAS && shamt >= (INT_WIDTH-1))? 2**(INT_WIDTH-1) : -round_int;
                flags_o.NV = a_decoded.exp >= BIAS && shamt > (INT_WIDTH-1) | (round_int > (2**(INT_WIDTH-1)));
            end
            else
            begin
                result_o = (a_decoded.exp >= BIAS && shamt >= (INT_WIDTH-1))? 2**(INT_WIDTH-1) : round_int;
                flags_o.NV = (a_decoded.exp >= BIAS && shamt > (INT_WIDTH-1))  | (round_int >= (2**(INT_WIDTH-1)));
            end
    end
end


//denormalize
assign shamt = (a_decoded.exp >= BIAS)? a_decoded.exp - BIAS : BIAS - a_decoded.exp;
assign pre_round_mant = (a_decoded.exp >= BIAS)?    {{INT_WIDTH-1{1'b0}}, a_info.is_normal, a_decoded.mant} << shamt 
                                                :   {{INT_WIDTH-1{1'b0}}, a_info.is_normal, a_decoded.mant} >> shamt;

//round bit and sticky bit
always_comb
begin
    if(a_decoded.exp >= BIAS)
    begin
        rs[1] = pre_round_mant[MANT_WIDTH-1];
        rs[0] = |pre_round_mant[MANT_WIDTH-2:0];
    end
    else
    begin
        rs[1] = pre_round_mant[MANT_WIDTH-1];
        rs[0] = stickybit;
    end
end

assign round_up =   ((rnd_i == RNE) & rs[1] & (pre_round_mant[MANT_WIDTH] | rs[0])) |
                    ((rnd_i == RDN) & a_decoded.sign  & (rs[1]   | rs[0])) |
                    ((rnd_i == RUP) & !a_decoded.sign & (rs[1]   | rs[0])) |
                    ((rnd_i == RMM) & rs[1]);

assign round_int = pre_round_mant[MANT_WIDTH+INT_WIDTH-1 -: INT_WIDTH] + round_up;

//sticky calculation
assign sigB = {a_info.is_normal, a_decoded.mant};
always_comb
    if(shamt == 0)
        stickybit = |sigB[MANT_WIDTH-2:0];
    else if(shamt == 1'b1)
        stickybit = |sigB[MANT_WIDTH-1:0];
    else
        stickybit = |sigB[MANT_WIDTH:0];

assign done_o = start_i;
endmodule