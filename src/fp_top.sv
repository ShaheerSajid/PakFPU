import fp_pkg::*;

module fp_top
#(
    parameter fp_format_e FP_FORMAT = FP32,
    parameter fp_format_e INT_FORMAT = INT32,

    localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT),
    localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT),
    localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT),
)
(
    input clk_i,
    input rst_i,

    input start_i,
    output ready_o,

    input [FP_WIDTH-1:0] a_i,
    input [FP_WIDTH-1:0] b_i,
    input [FP_WIDTH-1:0] c_i,

    input roundmode_e rnd_i,

    input float_op_e op_i,
    input [1:0] op_modify_i,

    output [FP_WIDTH-1:0] result_o,
    output valid_o,
    output status_t flags_o
);

/////////////////////////////////////////////////////////////////
// Internal Declarations
/////////////////////////////////////////////////////////////////
logic add_start;
logic add_done;

logic mul_start;
logic mul_done;

logic i2f_start;
logic i2f_done;

logic f2i_start;
logic f2i_done;

logic cmp_start;
logic cmp_done;

logic class_start;
logic class_done;

logic min_max_start;
logic min_max_done;

logic sgnj_start;
logic sgnj_done;

logic need_rnd;

// if fpformat == 64
//logic f2f_start;
//logic f2f_done;


/////////////////////////////////////////////////////////////////
// Func Decoder
/////////////////////////////////////////////////////////////////

//fadd: add, sub
//fmul
//fdiv: div, sqrt
//i2f: unsigned, signed
//f2i: unsigned, signed
//f2f: f2d, d2f
//fcmp: le, eq, lt
//fclass
//fmin
//fmax
//fsgnj: sgnj, sgnjn, sgnjx
//fmadd: madd, msub, nmadd, nmsub

assign add_start        = start_i & (op_i == FADD);
assign mul_start        = start_i & (op_i == FMUL);
assign i2f_start        = start_i & (op_i == I2F);
assign f2i_start        = start_i & (op_i == F2I);
assign cmp_start        = start_i & (op_i == FCMP);
assign class_start      = start_i & (op_i == FCLASSS);
assign min_max_start    = start_i & (op_i == FMIN | op_i == FMAX);
assign sgnj_start       = start_i & (op_i == FSGNJ);

assign need_rnd         = add_start | mul_start | i2f_start;

//lets leave double for now
//if fpformat == 64
//assign f2f_start        = start_i & (op_i == FSGNJNS | op_i == FSGNJS)

/////////////////////////////////////////////////////////////////
// Func blocks
/////////////////////////////////////////////////////////////////

fp_add #(.FP_FORMAT(FP_FORMAT)) fp_add_inst
(
    .a_i        (a_i),
    .b_i        (b_i),
    .start_i    (add_start),
    .sub        (op_modify_i == 2'b01),
    .rnd_i      (rnd_i),

    .result_o   (u_result_add),
    .done_o     (add_done),
    .rs_o       (rs_add),
    .round_en_o (round_en_add),
    .invalid_o  (invalid_add),
    .exp_cout_o (exp_cout_add)
);

fp_mul #(.FP_FORMAT(FP_FORMAT)) fp32_mul_inst
(
    .a_i        (a_i),
    .b_i        (b_i),
    .start_i    (mul_start),

    .result_o   (u_result_mul),
    .done_o     (mul_done),
    .rs_o       (rs_mul),
    .round_en_o (round_en_mul),
    .invalid_o  (invalid_mul),
    .exp_cout_o (exp_cout_mul)
);


//if input < INT_WIDTH: sign extend (this is to cater 32bit operands in 64bit cpu)
fp_i2f #(.FP_FORMAT(FP_FORMAT), .INT_FORMAT(INT_FORMAT)) fp_i2f_inst
(
    .a_i        (a_i),
    .start_i    (i2f_start),
    .signed_i   (op_modify_i == 2'b01),

    .result_o   (u_result_i2f),
    .done_o     (i2f_done),
    .rs_o       (rs_i2f),
    .round_en_o (round_en_i2f),
    .invalid_o  (invalid_i2f),
    .exp_cout_o (exp_cout_i2f)
);

//if output < INT_WIDTH: sign extend (this is to cater 32bit operands in 64bit cpu)
fp_f2i #(.FP_FORMAT(FP_FORMAT), .INT_FORMAT(INT_FORMAT)) fp_f2i_inst 
(
    .a_i        (a_i),
    .start_i    (f2i_start),
    .signed_i   (op_modify_i == 2'b01),
    .rnd_i      (rnd_i),

    .result_o   (result_f2i),
    .done_o     (f2i_done),
    .flags_o    (flags_o_f2i)
);

fp_cmp #(.FP_FORMAT(FP_FORMAT)) fp_cmp_inst
(
    .a_i        (a_i),
    .b_i        (b_i),
    .eq_en_i    (op_modify_i == 2'b01),
    .start_i    (cmp_start),

    .lt_o       (lt),
    .le_o       (le),
    .eq_o       (eq),
    .done_o     (cmp_done),
    .flags_o    (flags_o_cmp)
);

fp_class #(.FP_FORMAT(FP_FORMAT)) fp_class_inst
(
    .a_i        (a_i),
    .start_i    (class_start),
    .class_o    (classify),
    .done_o     (class_done),
);

//others min-max, sign injection

//If fpformat == 64
/*
//take care of nan boxing
f2d d2f_inst
(
    .a_i(a_i),
    .result_o(result_f2d),
    .flags_o(flags_o_f2d)
);

d2f d2f_inst
(
    .a_i(a_i),
    .result_o(result_d2f),
    .rs_o(rs_d2f),
    .round_en_o(round_en_d2f),
    .invalid_o(invalid_d2f),
    .exp_cout_o(exp_cout_d2f)
);
*/

/////////////////////////////////////////////////////////////////
// First Stage Arbiter
/////////////////////////////////////////////////////////////////
logic u_result_reg;
logic rs_reg;
logic round_en_reg;
logic invalid_reg;
logic exp_cout_reg;
logic done_reg;

assign done_reg = (((add_done | cmp_done) | (f2f_done | f2i_done)) | ((i2f_done | mul_done) | (sgnj_done | class_done))) | min_max_done;

always_comb
begin
    case(op_i)
      FADD: begin
        u_result_reg  = 
        rs_reg        =
        round_en_reg  =
        invalid_reg   =
        exp_cout_reg  =
      end
      FMUL: begin
      end
      FDIV: begin
      end
      I2F: begin
      end
      F2I: begin
      end
      F2F: begin
      end
      FCMP: begin
      end
      FCLASS: begin
      end
      FMIN: begin
      end
      FMAX: begin
      end
      FSGNJ: begin
      end
      FMADD: begin
      end
      default: begin
      end
    endcase
end

/////////////////////////////////////////////////////////////////
// Regwall
/////////////////////////////////////////////////////////////////
logic u_result_reg_rnd;
logic rs_reg_rnd;
logic round_en_reg_rnd;
logic invalid_reg_rnd;
logic exp_cout_reg_rnd;
logic done_reg_rnd;
logic need_rnd_reg_rnd;

always_ff @( posedge clk_i or negedge rst_i ) begin : pre_round_regwall
  if(!rst_i)

end
/////////////////////////////////////////////////////////////////
// Round
/////////////////////////////////////////////////////////////////

fp_rnd #(.FP_FORMAT(FP_FORMAT)) fp_rnd_inst
(
    .a_i        (u_result_reg_rnd),
    .rnd_i      (rnd_r),
    .rs_i       (rs_r),
    .round_en_i (round_en_r),
    .invalid_i  (invalid_r),
    .exp_cout_i (exp_cout_r),

    .out_o      (result_o),
    .flags_o    (flags_o)
);

/////////////////////////////////////////////////////////////////
// Output Mux
/////////////////////////////////////////////////////////////////


endmodule