// de1soc.sv — PakFPU board wrapper for Terasic DE1-SoC (Cyclone V 5CSEMA5F31C6)
//
// Synthesizes fp_top as FP32 by default. Key/switch mapping:
//   KEY[0]   : active-low asynchronous reset
//   KEY[1]   : start_i pulse
//   SW[3:0]  : float_op_e   (FADD=0 FMUL=1 FDIV=2 ... see fp_pkg)
//   SW[5:4]  : op_modify_i  (sub / sqrt / signed / etc.)
//   SW[8:6]  : roundmode_e  (RNE=0 RTZ=1 RDN=2 RUP=3 RMM=4)
//   SW[9]    : unused (tie low)
//
//   LEDR[9]  : valid_o
//   LEDR[8]  : ready_o
//   LEDR[4:0]: flags_o {NV DZ OF UF NX}
//   HEX[5:0] : result_o[23:0] (lower 24 bits, 6 hex digits)
//
// a_i / b_i / c_i are driven from a free-running counter so synthesis
// cannot optimize the FPU away. For actual measurements swap these
// with registered inputs fed from, e.g., JTAG or GPIO.

import fp_pkg::*;

module de1soc
(
    input              CLOCK_50,

    input  [3:0]       KEY,        // active-low pushbuttons
    input  [9:0]       SW,

    output [9:0]       LEDR,
    output [6:0]       HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);

// ----------------------------------------------------------------
// Free-running counter to exercise all FPU inputs
// ----------------------------------------------------------------
logic [63:0] ctr;
always_ff @(posedge CLOCK_50 or negedge KEY[0])
    if (!KEY[0]) ctr <= '0;
    else         ctr <= ctr + 1'b1;

logic [63:0] a_i, b_i, c_i;
assign a_i = ctr;
assign b_i = {ctr[31:0], ctr[63:32]};
assign c_i = {ctr[47:0], ctr[63:48]};

// ----------------------------------------------------------------
// FPU instance (FP32)
// ----------------------------------------------------------------
logic [63:0] result_o;
logic        valid_o, ready_o;
status_t     flags_o;

fp_top #(
    .FP_FORMAT  (FP32),
    .INT_FORMAT (INT32)
) fpu (
    .clk_i       (CLOCK_50),
    .rst_i       (KEY[0]),          // active-low
    .start_i     (~KEY[1]),         // KEY[1] pulled low = start

    .a_i         (a_i),
    .b_i         (b_i),
    .c_i         (c_i),

    .op_i        (float_op_e'(SW[3:0])),
    .op_modify_i (SW[5:4]),
    .rnd_i       (roundmode_e'(SW[8:6])),

    .result_o    (result_o),
    .valid_o     (valid_o),
    .ready_o     (ready_o),
    .flags_o     (flags_o)
);

// ----------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------
assign LEDR[9]   = valid_o;
assign LEDR[8]   = ready_o;
// Fold unobserved result bits (sign + upper exp) into LEDR[7:5] so
// Quartus cannot trim the corresponding logic paths.
assign LEDR[7:5] = result_o[31:29];   // sign + 2 exp msbs
assign LEDR[4:0] = flags_o;

hex7seg h0 (.d(result_o[3:0]),   .seg(HEX0));
hex7seg h1 (.d(result_o[7:4]),   .seg(HEX1));
hex7seg h2 (.d(result_o[11:8]),  .seg(HEX2));
hex7seg h3 (.d(result_o[15:12]), .seg(HEX3));
hex7seg h4 (.d(result_o[19:16]), .seg(HEX4));
hex7seg h5 (.d(result_o[23:20]), .seg(HEX5));

endmodule


// 7-segment hex display driver (active-low segments)
module hex7seg (input [3:0] d, output logic [6:0] seg);
always_comb case (d)
    4'h0: seg = 7'b1000000;
    4'h1: seg = 7'b1111001;
    4'h2: seg = 7'b0100100;
    4'h3: seg = 7'b0110000;
    4'h4: seg = 7'b0011001;
    4'h5: seg = 7'b0010010;
    4'h6: seg = 7'b0000010;
    4'h7: seg = 7'b1111000;
    4'h8: seg = 7'b0000000;
    4'h9: seg = 7'b0010000;
    4'ha: seg = 7'b0001000;
    4'hb: seg = 7'b0000011;
    4'hc: seg = 7'b1000110;
    4'hd: seg = 7'b0100001;
    4'he: seg = 7'b0000110;
    4'hf: seg = 7'b0001110;
    default: seg = 7'b1111111;
endcase
endmodule
