import fp_pkg::*;

module fp_top
#(
    parameter fp_format_e FP_FORMAT = FP32,
    parameter fp_format_e INT_FORMAT = INT32,

    localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT),
    localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT),
    localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT),
    localparam int unsigned INT_WIDTH = int_width(INT_FORMAT),
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

generate
  if(FP_FORMAT == FP64) begin
    logic f2d_start;
    logic f2d_done;
    logic d2f_start;
    logic d2f_done;
  end
endgenerate

logic need_rnd;

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

generate
  if(FP_FORMAT == FP64) begin
    assign f2f_start    = start_i & (op_i == FSGNJNS | op_i == FSGNJS)
  end
endgenerate


/////////////////////////////////////////////////////////////////
// Func blocks
/////////////////////////////////////////////////////////////////
Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t add_urnd_result;
Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t mul_urnd_result;
Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t d2f_urnd_result;
Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t i2f_urnd_result;
Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t div_urnd_result;
Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t madd_urnd_result;
Structs #(.FP_FORMAT(FP_FORMAT))::round_res_t f2d_rnd_result;

////////////////////
// Adder
////////////////////
fp_add #(.FP_FORMAT(FP_FORMAT)) fp_add_inst
(
  .a_i            (a_i),
  .b_i            (b_i),
  .start_i        (add_start),
  .sub            (op_modify_i == 2'b01),
  .rnd_i          (rnd_i),

  .urnd_result_o  (add_urnd_result),
  .done_o         (add_done)
);

////////////////////
// Multiply
////////////////////
fp_mul #(.FP_FORMAT(FP_FORMAT)) fp32_mul_inst
(
  .a_i            (a_i),
  .b_i            (b_i),
  .start_i        (mul_start),

  .urnd_result_o  (mul_urnd_result),
  .done_o         (mul_done)
);

////////////////////
// I2F
////////////////////
//if input < INT_WIDTH: sign extend (this is to cater 32bit operands in 64bit cpu)
fp_i2f #(.FP_FORMAT(FP_FORMAT), .INT_FORMAT(INT_FORMAT)) fp_i2f_inst
(
  .a_i            (a_i),
  .start_i        (i2f_start),
  .signed_i       (op_modify_i == 2'b01),

  .urnd_result_o  (i2f_urnd_result),
  .done_o         (i2f_done)
);

////////////////////
// F2I
////////////////////
logic [INT_WIDTH-1:0] f2i_result;
logic [INT_WIDTH-1:0] f2i_result_reg_rnd;
status_t f2i_flags;
status_t f2i_flags_reg_rnd;
//if output < INT_WIDTH: sign extend (this is to cater 32bit operands in 64bit cpu)
fp_f2i #(.FP_FORMAT(FP_FORMAT), .INT_FORMAT(INT_FORMAT)) fp_f2i_inst 
(
  .a_i            (a_i),
  .start_i        (f2i_start),
  .signed_i       (op_modify_i == 2'b01),
  .rnd_i          (rnd_i),

  .result_o       (f2i_result),
  .done_o         (f2i_done),
  .flags_o        (f2i_flags)
);

////////////////////
// CMP
////////////////////
logic [INT_WIDTH-1:0] cmp_result;
logic [INT_WIDTH-1:0] cmp_result_reg_rnd;
status_t cmp_flags;
status_t cmp_flags_reg_rnd;

fp_cmp #(.FP_FORMAT(FP_FORMAT)) fp_cmp_inst
(
  .a_i            (a_i),
  .b_i            (b_i),
  .eq_en_i        (op_modify_i == 2'b01),
  .start_i        (cmp_start),

  .lt_o           (lt),
  .le_o           (le),
  .eq_o           (eq),
  .done_o         (cmp_done),
  .flags_o        (cmp_flags)
);

////////////////////
// Classify
////////////////////
logic [INT_WIDTH-1:0] class_result;
logic [INT_WIDTH-1:0] class_result_reg_rnd;

fp_class #(.FP_FORMAT(FP_FORMAT)) fp_class_inst
(
  .a_i            (a_i),
  .start_i        (class_start),
  .class_o        (classify),
  .done_o         (class_done)
);

////////////////////
// Min/Max
////////////////////
//others min-max, sign injection

////////////////////
// F2F
////////////////////
generate
  if(FP_FORMAT == FP64) begin
    //take care of nan boxing
    f2d d2f_inst
    (
        .a_i(a_i),
        .rnd_result_o(f2d_rnd_result)
    );

    d2f d2f_inst
    (
        .a_i(a_i),
        .urnd_result_o  (d2f_urnd_result)
    );
  end
endgenerate

/////////////////////////////////////////////////////////////////
// First Stage Arbiter
/////////////////////////////////////////////////////////////////
Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t urnd_result_reg;
logic done_reg;

assign done_reg = (((add_done | cmp_done) | (f2f_done | f2i_done)) | ((i2f_done | mul_done) | (sgnj_done | class_done))) | min_max_done;

always_comb
begin
  urnd_result_reg = 'h0;
  f2i_result      = 'h0;
  f2i_flags       = 'h0;
  cmp_result      = 'h0;
  cmp_flags       = 'h0;
  class_result    = 'h0;

    case(op_i)
      FADD:   urnd_result_reg = add_urnd_result;
      FMUL:   urnd_result_reg = mul_urnd_result;
      FDIV:   urnd_result_reg = div_urnd_result;
      I2F:    urnd_result_reg = i2f_urnd_result;
      FMADD:  urnd_result_reg = madd_urnd_result;
      F2F:    urnd_result_reg = f2f_urnd_result;
      F2I: begin
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
    endcase
end

/////////////////////////////////////////////////////////////////
// Regwall
/////////////////////////////////////////////////////////////////
Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t urnd_result_reg_rnd;
logic done_reg_rnd;
logic need_rnd_reg_rnd;
roundmode_e rnd_reg;

always_ff @( posedge clk_i or negedge rst_i ) begin : pre_round_regwall
  if(!rst_i) begin
    urnd_result_reg_rnd <= 'h0;
    done_reg_rnd        <= 'h0;
    need_rnd_reg_rnd    <= 'h0;
    rnd_reg             <= 'h0;
  end
  else begin
    urnd_result_reg_rnd <= urnd_result_reg;
    done_reg_rnd        <= done_reg;
    need_rnd_reg_rnd    <= need_rnd;
    rnd_reg             <= rnd_i;
  end
end
/////////////////////////////////////////////////////////////////
// Round
/////////////////////////////////////////////////////////////////
Structs #(.FP_FORMAT(FP_FORMAT))::round_res_t rnd_result

fp_rnd #(.FP_FORMAT(FP_FORMAT)) fp_rnd_inst
(
  .urnd_result_i(urnd_result_reg_rnd),
  .rnd_i(rnd_reg),

  .rnd_result_o(rnd_result)
);

/////////////////////////////////////////////////////////////////
// Output Mux
/////////////////////////////////////////////////////////////////


endmodule