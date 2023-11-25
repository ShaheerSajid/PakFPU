import fp_pkg::*;

module fp_i2f
#(
    parameter fp_format_e FP_FORMAT = FP32,
    parameter int_format_e INT_FORMAT = INT32,


    localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT),
    localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT),
    localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT),
    localparam int unsigned INT_WIDTH = int_width(INT_FORMAT),
    localparam int unsigned SHIFT_WIDTH = maximum(FP_WIDTH, INT_WIDTH),
    localparam int unsigned BIAS = (2**(EXP_WIDTH-1)-1)

)
(
    input [INT_WIDTH-1:0] a_i,
    input start_i,
    input signed_i,
    output done_o,
    output Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t urnd_result_o
);
Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t result_o;
logic [1:0] rs_o;
logic round_en_o;
logic invalid_o;
logic [1:0] exp_cout_o;


/*
if unsigned -> sign = 1'b0;
if signed -> sign = input[31]

if signed take 2's compliment before shamt
*/

logic sign_o;
logic [EXP_WIDTH-1:0] exp_o;
logic [MANT_WIDTH-1:0] mant_o;

logic [INT_WIDTH-1:0] int_val;
logic [$clog2(INT_WIDTH)-1:0] shamt;

//width must be max of the two
logic [SHIFT_WIDTH-1:0] shift_out;



always_comb
begin
    if(a_i == 0)
    begin
        result_o = 0;
        round_en_o = 1'b0;
    end
    else
    begin
        result_o.sign = sign_o;
        result_o.exp = exp_o;
        result_o.mant = mant_o;
        round_en_o = 1'b1;
    end
end


assign int_val = (signed_i & a_i[INT_WIDTH-1])? -a_i : a_i;
//calculate shamt

logic [$clog2(INT_WIDTH)-1:0] shamt_lzc;
lzc #(.WIDTH(INT_WIDTH)) lzc_inst
(
    .a_i(int_val),
    .cnt_o(shamt_lzc),
    .zero_o()
);

assign shamt = (INT_WIDTH-1) - shamt_lzc;

//shift input
assign shift_out = {int_val, {SHIFT_WIDTH{1'b0}}} >> shamt;

assign sign_o = signed_i & a_i[INT_WIDTH-1];
assign mant_o = shift_out[SHIFT_WIDTH-1 -: MANT_WIDTH];
assign exp_o = BIAS + shamt;

assign rs_o[1] = shift_out[SHIFT_WIDTH-MANT_WIDTH-1];
assign rs_o[0] = |shift_out[SHIFT_WIDTH-MANT_WIDTH-2:0];

assign exp_cout_o = 2'b00;
assign invalid_o = 1'b0;

assign urnd_result_o.u_result =  result_o;
assign urnd_result_o.rs =  rs_o;
assign urnd_result_o.round_en =  round_en_o;
assign urnd_result_o.invalid =  invalid_o;
assign urnd_result_o.exp_cout =  exp_cout_o;

assign done_o = start_i;

endmodule