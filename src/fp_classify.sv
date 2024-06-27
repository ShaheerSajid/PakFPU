import fp_pkg::*;

module fp_classify
#(
    parameter fp_format_e FP_FORMAT = FP32,

    localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT)
)
(
    input [FP_WIDTH-1:0] a_i,
    input start_i,
    output classmask_e class_o,
    output done_o
);
`include "fp_class.sv"
/*
rs1 is −∞. 0xff800000
rs1 is a negative normal number. sign & exponent != 0 && exponent != 255
rs1 is a negative subnormal number. sign & exponent == 0 & mant != 0
rs1 is −0. 0x80000000
rs1 is +0. 0x00000000
rs1 is a positive subnormal number. exponent == 0 & mant != 0
rs1 is a positive normal number. exponent != 0 && exponent != 255
rs1 is +∞. 0x7f800000
rs1 is a signaling NaN. 0xx7f800001 - 0x7fbfffff, 0xff800001 - 0xffbfffff
rs1 is a quiet NaN. 0x7fc00000 - 0x7fffffff, 0xffc00000 - 0xffffffff
*/

fp_encoding_t a_decoded;
assign a_decoded = a_i;

fp_info_t a_info;
assign a_info = fp_info(a_i);

assign class_o[0] = a_info.is_inf       & a_info.is_minus;
assign class_o[1] = a_info.is_normal    & a_info.is_minus; 
assign class_o[2] = a_info.is_subnormal & a_info.is_minus;
assign class_o[3] = a_info.is_zero      & a_info.is_minus;
assign class_o[4] = a_info.is_zero      & !a_info.is_minus;
assign class_o[5] = a_info.is_subnormal & !a_info.is_minus;
assign class_o[6] = a_info.is_normal    & !a_info.is_minus; 
assign class_o[7] = a_info.is_inf       & !a_info.is_minus;
assign class_o[8] = a_info.is_signalling;
assign class_o[9] = a_info.is_quiet;

endmodule
