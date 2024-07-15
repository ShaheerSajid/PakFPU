import fp_pkg::*;

module fp_cmp
#(
    parameter fp_format_e FP_FORMAT = FP32,

    localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT),
    localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT),
    localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT)

)
(
    input [FP_WIDTH-1:0] a_i,
    input [FP_WIDTH-1:0] b_i,
    input start_i,
    input eq_en_i,
    output logic lt_o,
    output logic le_o,
    output logic eq_o,
    output done_o,
    output status_t flags_o
);
`include "fp_class.sv"
logic exp_eq, exp_lt, exp_gt;
logic mant_eq, mant_lt, mant_gt;
logic eq;
logic lt;
logic le;
logic invalid;

fp_encoding_t a_decoded;
fp_encoding_t b_decoded;

assign a_decoded = a_i;
assign b_decoded = b_i;

fp_info_t a_info;
fp_info_t b_info;

assign a_info = fp_info(a_i);
assign b_info = fp_info(b_i);


assign exp_eq = (a_decoded.exp == b_decoded.exp);
assign exp_lt = (a_decoded.exp < b_decoded.exp);
assign exp_gt = (a_decoded.exp > b_decoded.exp);

assign mant_eq = (a_decoded.mant == b_decoded.mant);
assign mant_lt = (a_decoded.mant < b_decoded.mant);
assign mant_gt = (a_decoded.mant > b_decoded.mant);

always_comb
begin
    if(a_info.is_zero & b_info.is_zero)
        lt = 1'b0;
    else
        case({a_decoded.sign, b_decoded.sign})
            2'b00: lt = (exp_lt | (exp_eq & mant_lt));
            2'b01: lt = 1'b0;
            2'b10: lt = 1'b1;
            2'b11: lt = (exp_gt | (exp_eq & mant_gt));
        endcase
end

assign eq = (a_info.is_zero & b_info.is_zero) | ((a_decoded.sign ~^ b_decoded.sign) & exp_eq & mant_eq);
assign le = lt | eq;

assign invalid = eq_en_i? (a_info.is_signalling | b_info.is_signalling) : (a_info.is_nan | b_info.is_nan);

assign flags_o.NV = invalid;
assign flags_o.OF = 1'b0;
assign flags_o.UF = 1'b0;
assign flags_o.NX = 1'b0;
assign flags_o.DZ = 1'b0;

assign lt_o = ~(a_info.is_nan | b_info.is_nan) & lt;
assign le_o = ~(a_info.is_nan | b_info.is_nan) & le;
assign eq_o = ~(a_info.is_nan | b_info.is_nan) & eq;

assign done_o = start_i;

endmodule