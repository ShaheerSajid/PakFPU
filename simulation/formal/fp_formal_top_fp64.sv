// fp_formal_top_fp64.sv — FP64 formal verification wrapper
//
// Co-instantiates fp_top (FP64, RISCV_MODE=1) and fp_props (FP_FORMAT=2).
// Used as the top-level module in fp_top_fp64.sby.
//
// Properties verified (same 9 assertions as FP32, applied to FP64 geometry):
//   P1  sNaN input raises NV
//   P2  NaN result is canonical qNaN (0x7FF8000000000000)
//   P3  FSGNJ never raises flags
//   P4  FCLASS never raises flags
//   P5  FDIV by zero raises DZ, not NV
//   P6  NaN-box violation produces canonical qNaN (RISCV_MODE only)
//   P7  ±Inf × ±0 raises NV
//   P8  valid_o is a single-cycle pulse
//   P9  ready_o deasserts after FDIV is accepted
//
// Note: FDIV (FP64) takes ~110 cycles to complete. BMC depth 32 covers protocol
// and exception-flag properties but does not reach FDIV completion.  Increase
// depth to ≥ 112 (or use prove mode) to verify P8/P9 for FDIV end-to-end.

`default_nettype none

module fp_formal_top_fp64 (
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
    .FP_FORMAT (2'd2),   // FP64
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
    .FP_FORMAT (2),      // FP64
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
