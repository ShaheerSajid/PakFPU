import fp_pkg::*;

module tb
`ifdef VERILATOR
(

    input [63:0] opA,
    input [63:0] opB,
    input [63:0] opC,
    input roundmode_e rnd,
    output [63:0] result,
    output status_t flags_o
)
`endif ;


`ifdef VERILATOR
logic [1:0] rs;
logic [63:0] u_result;
Structs #(.FP_FORMAT(FP32))::uround_res_t urnd_result;
Structs #(.FP_FORMAT(FP32))::round_res_t rnd_result;
logic round_en;
logic [1:0] exp_cout;
logic invalid;
logic lt,le,eq;
`else
logic [1:0] rs;
logic [31:0] result;
logic [31:0] u_result;
Structs #(.FP_FORMAT(FP32))::uround_res_t urnd_result;
Structs #(.FP_FORMAT(FP32))::round_res_t rnd_result;
logic round_en;
integer outfile0; 
logic [31:0] opA,opB,opC,exp_res;
logic [4:0] exc;
integer err_cnt;
integer test_cnt;
roundmode_e rnd;
logic [1:0] exp_cout;
status_t flags_o;
logic clk;
logic rst;
logic start;
logic valid;

initial begin
    outfile0=$fopen("testbench/test_rdn.txt","r");
    err_cnt = 0;
    test_cnt = 0;
    rnd = RDN;
    clk = 0;
    rst = 0;
    start = 0;
    repeat(5) #10;
    rst = 1;
    while (! $feof(outfile0)) begin
        $fscanf(outfile0,"%h %h %h %h %h\n",opA,opB,opC, exp_res,exc);
        //$fscanf(outfile0,"%h %h %h %h\n",opA,opB, exp_res,exc);
        //$fscanf(outfile0,"%h %h %h\n",opA,exp_res,exc);
        if(opA[30 -: 8] != 0 && opB[30 -: 8] != 0 && opC[30 -: 8] != 0 && opA[30 -: 8] != 255 && opB[30 -: 8] != 255 && opC[30 -: 8] != 255) begin
          /*start = 1;
          #10;
          start = 0;
          while(!valid) #10;*/
          #10;
          test_cnt = test_cnt + 1;
          if(exp_res != result /*|| flags_o != exc*/)
          begin
              $display("%h %h %h Expected=%h Actual=%h %h\t%b", opA,opB,opC, exp_res,result,exc,rs);
              //if(exp_res == 32'h00000000)
              if(err_cnt == 2)
              $stop();
              err_cnt = err_cnt + 1;
          end
        end
    end
    $display("Total Errors = %d/%d\t (%0.2f%%)", err_cnt, test_cnt, err_cnt*100.0/test_cnt);
    $fclose(outfile0);
    $stop();
end
//always #5 clk = ~clk;
`endif


fp_fma  #(.FP_FORMAT(FP32))fp_add_inst
(
    .a_i(opA),
    .b_i(opB),
    .c_i(opC),
    .sub_i(1'b0),
    .rnd_i(rnd),

    .urnd_result_o(urnd_result)
);

// fp_add  #(.FP_FORMAT(FP32))fp_add_inst
// (
//     .a_i(opA),
//     .b_i(opB),
//     .sub_i(1'b0),
//     .rnd_i(rnd),

//     .urnd_result_o(urnd_result)
// );

// fp_div #(.FP_FORMAT(FP32))fp_div_inst
// (

//     .clk_i(clk),
//     .reset_i(rst),
//     .a_i(opA),
//     .b_i(opB),
//     .start_i(start),
//     .rnd_i(rnd),

//     .urnd_result_o(urnd_result),
//     .done_o(valid)
// );

// fp_mul #(.FP_FORMAT(FP32))fp_mul_inst
// (
//     .a_i(opA),
//     .b_i(opB),

//     .urnd_result_o(urnd_result)
// );

//if input < INT_WIDTH sign extend
// fp_i2f #(.FP_FORMAT(FP32), .INT_FORMAT(INT32))fp_i2f_inst
// (
//     .a_i(opA),
//     .signed_i(1'b1),
//     .urnd_result_o(urnd_result)
// );

// d2f d2f_inst
// (
//     .a_i(opA),
//     .urnd_result_o(urnd_result)
// );

// f2d f2d_inst
// (
//     .a_i(opA),
//     .rnd_result_o(rnd_result)
// );

fp_rnd #(.FP_FORMAT(FP32))fp_rnd_inst
(
    .urnd_result_i(urnd_result),
    .rnd_i(rnd),

    .rnd_result_o(rnd_result)
);

//if output < INT_WIDTH sign extend
// fp_f2i #(.FP_FORMAT(FP32), .INT_FORMAT(INT64))fp_f2i_inst
// (
//     .a_i(opA),
//     .signed_i(1'b1),
//     .rnd_i(rnd),
//     .result_o(result),
//     .flags_o(flags_o)
// );


assign result = urnd_result.u_result;
assign flags_o = rnd_result.flags;

/*
fp_cmp fp_cmp_inst
(
    .a_i(opA),
    .b_i(opB),
    .eq_en_i(1'b1),
    .lt_o(lt),
    .le_o(le),
    .eq_o(eq),
    .flags_o(flags_o)
);
assign result = eq;
*/

endmodule
