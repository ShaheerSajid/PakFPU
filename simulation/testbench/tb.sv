import fp_pkg::*;

module tb
`ifdef VERILATOR
(
    input clk,
    input rst,
    input start,
    output valid,
    input [63:0] opA,
    input [63:0] opB,
    input [63:0] opC,
    input roundmode_e rnd,
    output [63:0] result,
    output status_t flags_o
)
`endif
;

parameter int unsigned FP_FORMAT_I  = 0;
parameter int unsigned INT_FORMAT_I = 0;
parameter int unsigned OP_SEL_I     = 2;
parameter int unsigned OP_MODIFY_I  = 0;
parameter int unsigned RISCV_MODE_I = 0;  // 1 = RISC-V mode, 0 = IEEE 754-2019

localparam fp_format_e  FP_FORMAT  = fp_format_e'(FP_FORMAT_I);
localparam int_format_e INT_FORMAT = int_format_e'(INT_FORMAT_I);
localparam float_op_e   OP_SEL     = float_op_e'(OP_SEL_I);
localparam logic [1:0]  OP_MODIFY  = OP_MODIFY_I[1:0];
localparam logic        RISCV_MODE = logic'(RISCV_MODE_I[0]);

logic [63:0] dut_a;
logic [63:0] dut_b;
logic [63:0] dut_c;
logic [63:0] dut_result;
status_t dut_flags;
logic dut_valid;
logic dut_ready;

`ifdef VERILATOR
assign dut_a = opA;
assign dut_b = opB;
assign dut_c = opC;
assign valid = dut_valid;
assign result = dut_result;
assign flags_o = dut_flags;
`else
logic clk;
logic rst;
logic start;
logic valid;
logic ready;
logic [63:0] opA;
logic [63:0] opB;
logic [63:0] opC;
logic [63:0] result;
logic [63:0] exp_res;
status_t flags_o;
logic [4:0] exc;
roundmode_e rnd;
integer outfile0;
integer err_cnt;
integer test_cnt;

assign dut_a = opA;
assign dut_b = opB;
assign dut_c = opC;
assign result = dut_result;
assign valid = dut_valid;
assign flags_o = dut_flags;
`endif

fp_top #(
    .FP_FORMAT (FP_FORMAT),
    .INT_FORMAT(INT_FORMAT),
    .RISCV_MODE(RISCV_MODE)
) dut
(
    .clk_i(clk),
    .rst_i(rst),
    .start_i(start),
    .ready_o(dut_ready),
    .a_i(dut_a),
    .b_i(dut_b),
    .c_i(dut_c),
    .rnd_i(rnd),
    .op_i(OP_SEL),
    .op_modify_i(OP_MODIFY),
    .result_o(dut_result),
    .valid_o(dut_valid),
    .flags_o(dut_flags)
);

`ifndef VERILATOR
initial begin
    outfile0 = $fopen("testbench/test_rtz.txt", "r");
    err_cnt = 0;
    test_cnt = 0;
    rnd = RTZ;
    clk = 0;
    rst = 0;
    start = 0;
    opC = '0;

    repeat (5) #10;
    rst = 1;

    while (!$feof(outfile0)) begin
        // Expected format: A B EXPECTED FLAGS
        $fscanf(outfile0, "%h %h %h %h\n", opA, opB, exp_res, exc);

        start = 1'b1;
        #10;
        start = 1'b0;
        while (!valid) #10;

        test_cnt = test_cnt + 1;
        if (exp_res != result || flags_o != exc) begin
            $display("%h %h %h Expected=%h Actual=%h Ex.flags=%b Ac.flags=%b",
                     opA, opB, opC, exp_res, result, exc, flags_o);
            err_cnt = err_cnt + 1;
            $stop();
        end
    end

    $display("Total Errors = %d/%d\t (%0.2f%%)", err_cnt, test_cnt, err_cnt * 100.0 / test_cnt);
    $fclose(outfile0);
    $stop();
end

always #5 clk = ~clk;
`endif

endmodule
