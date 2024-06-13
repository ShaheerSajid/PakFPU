import fp_pkg::*;

module fp_rnd
#(
    parameter fp_format_e FP_FORMAT = FP32,

    localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT),
    localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT),
    localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT)
)
(
    input Structs #(.FP_FORMAT(FP_FORMAT))::uround_res_t urnd_result_i,
    input roundmode_e rnd_i,
    input round_only,
    output Structs #(.FP_FORMAT(FP_FORMAT))::round_res_t rnd_result_o
);

Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t a_i;
logic [1:0] rs_i;
logic round_en_i;
logic invalid_i;
logic [1:0] exp_cout_i;

Structs #(.FP_FORMAT(FP_FORMAT))::fp_encoding_t out_o;
status_t flags_o;


logic round_bit;
logic sticky_bit;

logic uround_bit;
logic usticky_bit;
logic round_out;

logic round_up;
logic [MANT_WIDTH+1:0] rounded_mant;

logic uround_up;
logic [MANT_WIDTH:0] urounded_mant;

logic sign_o;
logic [EXP_WIDTH+1:0] exp_o;
logic [MANT_WIDTH-1:0] mant_o;

logic usign_o;
logic [EXP_WIDTH-1:0] uexp_o;
logic [MANT_WIDTH-1:0] umant_o;

logic ovf;
logic uf;

logic [EXP_WIDTH-1:0] denorm_shift;
logic [EXP_WIDTH:0] stickyindex;
logic [MANT_WIDTH:0] sigB;
logic [MANT_WIDTH:0] compressed_mant;
logic new_stickybit;


assign a_i        = urnd_result_i.u_result;
assign rs_i       = urnd_result_i.rs;
assign round_en_i = urnd_result_i.round_en;
assign invalid_i  = urnd_result_i.invalid;
assign exp_cout_i = urnd_result_i.exp_cout;

assign round_bit = rs_i[1];
assign sticky_bit = rs_i[0];

assign uround_bit = round_out;
assign usticky_bit = |rs_i[1:0] | new_stickybit;

//round
assign round_up =   ((rnd_i == RNE) & round_bit & (a_i.mant[0] | sticky_bit)) |
                    ((rnd_i == RDN) & a_i.sign  & (round_bit   | sticky_bit)) |
                    ((rnd_i == RUP) & !a_i.sign & (round_bit   | sticky_bit)) |
                    ((rnd_i == RMM) & round_bit);

assign uround_up =  ((rnd_i == RNE) & uround_bit & (umant_o[0] | usticky_bit)) |
                    ((rnd_i == RDN) & a_i.sign  & (uround_bit   | usticky_bit)) |
                    ((rnd_i == RUP) & !a_i.sign & (uround_bit   | usticky_bit)) |
                    ((rnd_i == RMM) & uround_bit);

assign rounded_mant = {2'b01, a_i.mant} + round_up;
assign urounded_mant = {1'b0, umant_o} + uround_up;

//re noramlize if needed
assign sign_o = a_i.sign;
assign exp_o = (round_en_i & rounded_mant[MANT_WIDTH+1])? {exp_cout_i, a_i.exp} + 1'b1 : {exp_cout_i, a_i.exp};
assign mant_o = round_en_i? (rounded_mant[MANT_WIDTH+1]? rounded_mant[MANT_WIDTH:1] : rounded_mant[MANT_WIDTH-1:0]) : a_i.mant;

assign ovf  = round_en_i && ($signed(exp_o) >= $signed(2**EXP_WIDTH-1));
assign uf   = round_en_i && ($signed(exp_o) <= $signed(0)) & (uround_bit | usticky_bit);

assign flags_o.NV = invalid_i;
assign flags_o.OF = ovf;
assign flags_o.UF = uf;
assign flags_o.NX = round_en_i && ((round_bit | sticky_bit) | uf | ovf);
assign flags_o.DZ = 1'b0;

always_comb
begin
    if(round_en_i && flags_o.OF)
    begin
        out_o.sign = sign_o;
        case(rnd_i)
            RNE, RMM: begin
                out_o.exp  = (2**EXP_WIDTH-1);
                out_o.mant = 0;
            end
            RTZ     : begin
                out_o.exp  = (2**EXP_WIDTH-2);
                out_o.mant = {MANT_WIDTH{1'b1}};
            end
            RDN     : begin
                if(!sign_o)
                begin
                    out_o.exp  = (2**EXP_WIDTH-2);
                    out_o.mant = {MANT_WIDTH{1'b1}};
                end
                else
                begin
                    out_o.exp  = (2**EXP_WIDTH-1);
                    out_o.mant = 0;
                end
            end
            RUP     : begin
                if(~sign_o)
                begin
                    out_o.exp  = (2**EXP_WIDTH-1);
                    out_o.mant = 0;
                end
                else
                begin
                    out_o.exp  = (2**EXP_WIDTH-2);
                    out_o.mant = {MANT_WIDTH{1'b1}};
                end
            end
            default : begin
                out_o.exp  = exp_o;
                out_o.mant = mant_o;
            end
        endcase
    end
    else if(round_en_i && $signed(exp_o) <= $signed(0) && !round_only)
    begin
        out_o.sign  = usign_o;
        out_o.exp  = urounded_mant[MANT_WIDTH]? 'd1 : 'd0;
        out_o.mant  = urounded_mant[MANT_WIDTH-1:0];
    end
    else
    begin
        out_o.sign  = sign_o;
        out_o.exp  = exp_o;
        out_o.mant  = mant_o;
    end 
end

//denormalize logic
assign denorm_shift = $signed(0)-$signed(a_i.exp);
always_comb
begin
    usign_o = a_i.sign;
    uexp_o = {EXP_WIDTH{1'b0}};
    {umant_o, round_out} = {1'b1, a_i.mant[MANT_WIDTH-1:1], a_i.mant[0]} >> denorm_shift;
end

//new sticky logic
assign sigB = {1'b1, a_i.mant[MANT_WIDTH-1:0]};
genvar i;
generate
    for(i = 0; i <= MANT_WIDTH; i= i+1)
	begin : combine_sig
        assign compressed_mant[i] = |sigB[i:0];
	end
endgenerate
assign stickyindex = denorm_shift - 1;

always_comb
    if($signed(stickyindex) < $signed(0))
        new_stickybit = 1'b0;
    else if($signed(stickyindex) > $signed(MANT_WIDTH))
        new_stickybit = compressed_mant[MANT_WIDTH];
    else
        new_stickybit = compressed_mant[stickyindex];

assign rnd_result_o.result = out_o;
assign rnd_result_o.flags = flags_o;
endmodule