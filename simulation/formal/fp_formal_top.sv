// fp_formal_top.sv — formal verification wrapper
//
// Co-instantiates fp_top (DUT, from fp_rtl.v) and fp_props (checker).
// Used as the top-level module in fp_top.sby instead of using SV 'bind'.

`default_nettype none

module fp_formal_top (
    input  logic          clk_i,
    input  logic          rst_i,
    input  logic          start_i,
    output logic          ready_o,
    input  logic [63:0]   a_i,
    input  logic [63:0]   b_i,
    input  logic [63:0]   c_i,
    input  logic [2:0]    rnd_i,
    input  logic [3:0]    op_i,
    input  logic [1:0]    op_modify_i,
    output logic [63:0]   result_o,
    output logic          valid_o,
    output logic [4:0]    flags_o
);

fp_top #(
    .FP_FORMAT (2'd0),
    .INT_FORMAT(1'b0),
    .RISCV_MODE(1'b1)
) dut (
    .clk_i      (clk_i),
    .rst_i      (rst_i),
    .start_i    (start_i),
    .ready_o    (ready_o),
    .a_i        (a_i),
    .b_i        (b_i),
    .c_i        (c_i),
    .rnd_i      (rnd_i),
    .op_i       (op_i),
    .op_modify_i(op_modify_i),
    .result_o   (result_o),
    .valid_o    (valid_o),
    .flags_o    (flags_o)
);

fp_props #(
    .FP_FORMAT (0),
    .INT_FORMAT(0),
    .RISCV_MODE(1'b1)
) chk (
    .clk_i      (clk_i),
    .rst_i      (rst_i),
    .start_i    (start_i),
    .ready_o    (ready_o),
    .a_i        (a_i),
    .b_i        (b_i),
    .c_i        (c_i),
    .rnd_i      (rnd_i),
    .op_i       (op_i),
    .op_modify_i(op_modify_i),
    .result_o   (result_o),
    .valid_o    (valid_o),
    .flags_o    (flags_o)
);

endmodule
