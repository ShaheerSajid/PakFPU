module fp_top
import fp_pkg::*;
#(
    parameter fp_format_e  FP_FORMAT   = FP32,
    parameter int_format_e INT_FORMAT  = INT32,
    // When RISCV_MODE=1:
    //   - NaN boxing enforced on FP32 inputs (upper 32 bits must be 0xFFFFFFFF)
    //   - All NaN outputs replaced with the canonical quiet NaN
    //   - FMIN/FMAX return the non-NaN operand when exactly one input is NaN
    //     (IEEE 754-2008 minNum/maxNum, required by the RISC-V ISA spec)
    // When RISCV_MODE=0 (IEEE 754-2019 general):
    //   - Inputs accepted as-is regardless of upper bits
    //   - NaN payload preserved in results
    //   - FMIN/FMAX propagate NaN when either operand is NaN
    parameter logic        RISCV_MODE  = 1'b0
)
(
    input clk_i,
    input rst_i,

    input start_i,
    output logic ready_o,

    input [63:0] a_i,
    input [63:0] b_i,
    input [63:0] c_i,

    input roundmode_e rnd_i,

    input float_op_e op_i,
    input [1:0] op_modify_i,

    output logic [63:0] result_o,
    output logic valid_o,
    output status_t flags_o
);
localparam int unsigned FP_WIDTH   = fp_width(FP_FORMAT);
localparam int unsigned EXP_WIDTH  = exp_bits(FP_FORMAT);
localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT);
localparam int unsigned INT_WIDTH  = int_width(INT_FORMAT);
`include "fp_defs.svh"

localparam logic [FP_WIDTH-1:0] QNAN_FP = {1'b0, {EXP_WIDTH{1'b1}}, 1'b1, {MANT_WIDTH-1{1'b0}}};

/////////////////////////////////////////////////////////////////
// Input decode helpers
/////////////////////////////////////////////////////////////////
fp_encoding_t a_decoded;
fp_encoding_t b_decoded;
logic [FP_WIDTH-1:0] a_fp;
logic [FP_WIDTH-1:0] b_fp;
logic [FP_WIDTH-1:0] c_fp;

// NaN boxing (RISC-V ISA spec §11.2): for FP32 operations the upper 32 bits of
// each 64-bit register must be all-1s. If not, the value is treated as the
// canonical quiet NaN.  In IEEE 754 general mode inputs pass through unchanged.
generate
    if (RISCV_MODE && FP_FORMAT == FP32) begin : gen_nanbox
        assign a_fp = (a_i[63:32] == 32'hFFFF_FFFF) ? a_i[31:0] : QNAN_FP;
        assign b_fp = (b_i[63:32] == 32'hFFFF_FFFF) ? b_i[31:0] : QNAN_FP;
        assign c_fp = (c_i[63:32] == 32'hFFFF_FFFF) ? c_i[31:0] : QNAN_FP;
    end else begin : gen_no_nanbox
        assign a_fp = a_i[FP_WIDTH-1:0];
        assign b_fp = b_i[FP_WIDTH-1:0];
        assign c_fp = c_i[FP_WIDTH-1:0];
    end
endgenerate
assign a_decoded = a_fp;
assign b_decoded = b_fp;

fp_info_t a_info;
fp_info_t b_info;
assign a_info = fp_info(a_fp);
assign b_info = fp_info(b_fp);

logic [INT_WIDTH-1:0] a_int;
logic [31:0] a_fp32;
logic [63:0] a_fp64;
assign a_int = a_i[INT_WIDTH-1:0];
assign a_fp32 = a_i[31:0];
assign a_fp64 = a_i;

/////////////////////////////////////////////////////////////////
// Start / busy decode
/////////////////////////////////////////////////////////////////
logic longop_busy_q;
logic longop_sqrt_q;
roundmode_e longop_rnd_q;

logic fma_busy_q;
roundmode_e fma_rnd_q;

logic accept_start;
logic fdv_start;

logic add_start;
logic mul_start;
logic div_start;
logic sqrt_start;
logic i2f_start;
logic f2i_start;
logic cmp_start;
logic class_start;
logic minmax_start;
logic sgnj_start;
logic fma_start;
logic f2f_start;

assign ready_o = ~longop_busy_q & ~fma_busy_q;
assign accept_start = start_i & ready_o;

assign add_start = accept_start & (op_i == FADD);
assign mul_start = accept_start & (op_i == FMUL);
assign fdv_start = accept_start & (op_i == FDIV);
assign div_start = fdv_start & ~op_modify_i[0];
assign sqrt_start = fdv_start & op_modify_i[0];
assign i2f_start = accept_start & (op_i == I2F);
assign f2i_start = accept_start & (op_i == F2I);
assign cmp_start = accept_start & (op_i == FCMP);
assign class_start = accept_start & (op_i == FCLASS);
assign minmax_start = accept_start & ((op_i == FMIN) || (op_i == FMAX));
assign sgnj_start = accept_start & (op_i == FSGNJ);
assign fma_start = accept_start & (op_i == FMADD);
assign f2f_start = accept_start & (op_i == F2F);

logic div_done;
logic sqrt_done;
always_ff @(posedge clk_i or negedge rst_i) begin
    if (!rst_i) begin
        longop_busy_q <= 1'b0;
        longop_sqrt_q <= 1'b0;
        longop_rnd_q <= RNE;
    end else begin
        if (fdv_start) begin
            longop_busy_q <= 1'b1;
            longop_sqrt_q <= op_modify_i[0];
            longop_rnd_q <= rnd_i;
        end else if ((longop_sqrt_q && sqrt_done) || (~longop_sqrt_q && div_done)) begin
            longop_busy_q <= 1'b0;
        end
    end
end

// FMADD has 1-cycle pipeline latency (done_o fires one cycle after start_i).
// Block ready_o for that cycle so no other operation can clobber op_sel and
// cause the arbiter to miss capturing the FMADD result.
always_ff @(posedge clk_i or negedge rst_i) begin
    if (!rst_i) begin
        fma_busy_q <= 1'b0;
        fma_rnd_q  <= RNE;
    end else begin
        if (fma_start) begin
            fma_busy_q <= 1'b1;
            fma_rnd_q  <= rnd_i;
        end else if (fma_done) begin
            fma_busy_q <= 1'b0;
        end
    end
end

/////////////////////////////////////////////////////////////////
// Function blocks
/////////////////////////////////////////////////////////////////
uround_res_t add_urnd_result;
logic add_done;
fp_add #(.FP_FORMAT(FP_FORMAT)) fp_add_inst
(
    .a_i(a_fp),
    .b_i(b_fp),
    .start_i(add_start),
    .sub_i(op_modify_i == 2'b01),
    .rnd_i(rnd_i),
    .done_o(add_done),
    .urnd_result_o(add_urnd_result)
);

uround_res_t mul_urnd_result;
logic mul_done;
fp_mul #(.FP_FORMAT(FP_FORMAT)) fp_mul_inst
(
    .a_i(a_fp),
    .b_i(b_fp),
    .start_i(mul_start),
    .done_o(mul_done),
    .urnd_result_o(mul_urnd_result)
);

uround_res_t div_urnd_result;
logic div_by_zero;
fp_div #(.FP_FORMAT(FP_FORMAT)) fp_div_inst
(
    .clk_i(clk_i),
    .reset_i(rst_i),
    .a_i(a_fp),
    .b_i(b_fp),
    .start_i(div_start),
    .rnd_i(rnd_i),
    .done_o(div_done),
    .urnd_result_o(div_urnd_result),
    .divide_by_zero(div_by_zero)
);

uround_res_t sqrt_urnd_result;
fp_sqrt #(.FP_FORMAT(FP_FORMAT)) fp_sqrt_inst
(
    .clk_i(clk_i),
    .reset_i(rst_i),
    .a_i(a_fp),
    .start_i(sqrt_start),
    .rnd_i(rnd_i),
    .done_o(sqrt_done),
    .urnd_result_o(sqrt_urnd_result)
);

uround_res_t i2f_urnd_result;
logic i2f_done;
fp_i2f #(.FP_FORMAT(FP_FORMAT), .INT_FORMAT(INT_FORMAT)) fp_i2f_inst
(
    .a_i(a_int),
    .start_i(i2f_start),
    .signed_i(op_modify_i == 2'b01),
    .done_o(i2f_done),
    .urnd_result_o(i2f_urnd_result)
);

logic [INT_WIDTH-1:0] f2i_result;
status_t f2i_flags;
logic f2i_done;
fp_f2i #(.FP_FORMAT(FP_FORMAT), .INT_FORMAT(INT_FORMAT)) fp_f2i_inst
(
    .a_i(a_fp),
    .signed_i(op_modify_i == 2'b01),
    .start_i(f2i_start),
    .rnd_i(rnd_i),
    .result_o(f2i_result),
    .flags_o(f2i_flags),
    .done_o(f2i_done)
);

logic cmp_lt;
logic cmp_le;
logic cmp_eq;
status_t cmp_flags;
logic cmp_done;
fp_cmp #(.FP_FORMAT(FP_FORMAT)) fp_cmp_inst
(
    .a_i(a_fp),
    .b_i(b_fp),
    .start_i(cmp_start),
    .eq_en_i(op_modify_i == 2'b01),
    .lt_o(cmp_lt),
    .le_o(cmp_le),
    .eq_o(cmp_eq),
    .done_o(cmp_done),
    .flags_o(cmp_flags)
);

classmask_e class_mask;
logic class_done;
fp_classify #(.FP_FORMAT(FP_FORMAT)) fp_classify_inst
(
    .a_i(a_fp),
    .start_i(class_start),
    .class_o(class_mask),
    .done_o(class_done)
);

logic [FP_WIDTH-1:0] fma_a_i;
assign fma_a_i = {a_fp[FP_WIDTH-1] ^ op_modify_i[1], a_fp[FP_WIDTH-2:0]};

uround_res_t fma_urnd_result;
logic fma_done;
logic fma_round_only;
logic fma_mul_ovf;
logic fma_mul_uf;
logic fma_mul_uround_out;
fp_fma #(.FP_FORMAT(FP_FORMAT)) fp_fma_inst
(
    .clk_i(clk_i),
    .reset_i(rst_i),
    .a_i(fma_a_i),
    .b_i(b_fp),
    .c_i(c_fp),
    .start_i(fma_start),
    .sub_i(op_modify_i[0]),
    .rnd_i(rnd_i),
    .done_o(fma_done),
    .round_only(fma_round_only),
    .mul_ovf(fma_mul_ovf),
    .mul_uf(fma_mul_uf),
    .mul_uround_out(fma_mul_uround_out),
    .urnd_result_o(fma_urnd_result)
);

/////////////////////////////////////////////////////////////////
// F2F blocks
/////////////////////////////////////////////////////////////////
uround_res_t f2f_urnd_result;
logic [FP_WIDTH-1:0] f2f_direct_result;
status_t f2f_direct_flags;
logic f2f_done;
logic f2f_need_rnd;

round_res_t f2d_rnd_result;
uround_res_t d2f_urnd_result;

generate
    if (FP_FORMAT == FP64) begin : gen_f2d
        f2d f2d_inst
        (
            .a_i(a_fp32),
            .rnd_result_o(f2d_rnd_result)
        );

        assign f2f_done = f2f_start;
        assign f2f_need_rnd = 1'b0;
        assign f2f_direct_result = f2d_rnd_result.result;
        assign f2f_direct_flags = f2d_rnd_result.flags;
        assign f2f_urnd_result = '0;
    end else if (FP_FORMAT == FP32) begin : gen_d2f
        d2f d2f_inst
        (
            .a_i(a_fp64),
            .urnd_result_o(d2f_urnd_result)
        );

        assign f2f_done = f2f_start;
        assign f2f_need_rnd = 1'b1;
        assign f2f_urnd_result = d2f_urnd_result;
        assign f2f_direct_result = '0;
        assign f2f_direct_flags = '0;
    end else begin : gen_no_f2f
        assign f2f_done = 1'b0;
        assign f2f_need_rnd = 1'b0;
        assign f2f_urnd_result = '0;
        assign f2f_direct_result = '0;
        assign f2f_direct_flags = '0;
    end
endgenerate

/////////////////////////////////////////////////////////////////
// Min/Max + Sgnj
/////////////////////////////////////////////////////////////////
logic [FP_WIDTH-1:0] minmax_result;
status_t minmax_flags;
logic minmax_done;
assign minmax_done = minmax_start;

always_comb begin
    minmax_flags = '0;
    minmax_flags.NV = a_info.is_signalling | b_info.is_signalling;

    // NaN handling:
    //   RISCV_MODE=1 (IEEE 754-2008 minNum/maxNum): return the non-NaN operand
    //     when exactly one input is NaN; both-NaN → canonical qNaN.
    //   RISCV_MODE=0 (IEEE 754-2019 minimum/maximum): propagate NaN whenever
    //     either operand is NaN.
    if (a_info.is_nan || b_info.is_nan) begin
        if (RISCV_MODE && a_info.is_nan && !b_info.is_nan)
            minmax_result = b_fp;
        else if (RISCV_MODE && b_info.is_nan && !a_info.is_nan)
            minmax_result = a_fp;
        else
            minmax_result = QNAN_FP;
    end else if (a_info.is_zero && b_info.is_zero) begin
        minmax_result = '0;
        if (op_i == FMIN) begin
            minmax_result[FP_WIDTH-1] = a_decoded.sign | b_decoded.sign;
        end else begin
            minmax_result[FP_WIDTH-1] = a_decoded.sign & b_decoded.sign;
        end
    end else if (op_i == FMIN) begin
        minmax_result = cmp_lt ? a_fp : b_fp;
    end else begin
        minmax_result = cmp_lt ? b_fp : a_fp;
    end
end

logic [FP_WIDTH-1:0] sgnj_result;
status_t sgnj_flags;
logic sgnj_done;
assign sgnj_done = sgnj_start;

always_comb begin
    sgnj_flags = '0;
    sgnj_result = a_fp;
    case (op_modify_i)
        2'b00: sgnj_result[FP_WIDTH-1] = b_decoded.sign;
        2'b01: sgnj_result[FP_WIDTH-1] = ~b_decoded.sign;
        2'b10: sgnj_result[FP_WIDTH-1] = a_decoded.sign ^ b_decoded.sign;
        default: sgnj_result[FP_WIDTH-1] = b_decoded.sign;
    endcase
end

/////////////////////////////////////////////////////////////////
// Direct-result formatting for non-round ops
/////////////////////////////////////////////////////////////////
logic [63:0] f2i_result_fp;
logic signed [63:0] f2i_result_signed_ext;
logic [63:0] f2i_result_unsigned_ext;
assign f2i_result_signed_ext = $signed(f2i_result);
assign f2i_result_unsigned_ext = f2i_result;
assign f2i_result_fp = op_modify_i[0] ? f2i_result_signed_ext : f2i_result_unsigned_ext;

logic cmp_bit;
always_comb begin
    case (op_modify_i)
        2'b00: cmp_bit = cmp_le;
        2'b01: cmp_bit = cmp_eq;
        default: cmp_bit = cmp_lt;
    endcase
end

logic [63:0] cmp_result_fp;
assign cmp_result_fp = {{63{1'b0}}, cmp_bit};

logic [63:0] class_result_fp;
assign class_result_fp = {{54{1'b0}}, class_mask};

/////////////////////////////////////////////////////////////////
// First stage arbiter
/////////////////////////////////////////////////////////////////
float_op_e op_sel;
logic fdv_sqrt_sel;
roundmode_e rnd_sel;

assign op_sel = longop_busy_q ? FDIV : (fma_busy_q ? FMADD : op_i);
assign fdv_sqrt_sel = longop_busy_q ? longop_sqrt_q : op_modify_i[0];

uround_res_t urnd_sel;
logic [63:0] direct_result_sel;
status_t direct_flags_sel;
logic done_sel;
logic need_rnd_sel;
logic round_only_sel;
logic mul_ovf_sel;
logic mul_uf_sel;
logic mul_uround_out_sel;
logic dz_sel;

always_comb begin
    urnd_sel = '0;
    direct_result_sel = '0;
    direct_flags_sel = '0;
    done_sel = 1'b0;
    need_rnd_sel = 1'b0;
    round_only_sel = 1'b0;
    mul_ovf_sel = 1'b0;
    mul_uf_sel = 1'b0;
    mul_uround_out_sel = 1'b0;
    dz_sel = 1'b0;
    rnd_sel = rnd_i;

    case (op_sel)
        FADD: begin
            urnd_sel = add_urnd_result;
            done_sel = add_done;
            need_rnd_sel = 1'b1;
        end
        FMUL: begin
            urnd_sel = mul_urnd_result;
            done_sel = mul_done;
            need_rnd_sel = 1'b1;
        end
        FDIV: begin
            urnd_sel = fdv_sqrt_sel ? sqrt_urnd_result : div_urnd_result;
            done_sel = fdv_sqrt_sel ? sqrt_done : div_done;
            need_rnd_sel = 1'b1;
            dz_sel = (~fdv_sqrt_sel) & div_by_zero;
            rnd_sel = longop_busy_q ? longop_rnd_q : rnd_i;
        end
        I2F: begin
            urnd_sel = i2f_urnd_result;
            done_sel = i2f_done;
            need_rnd_sel = 1'b1;
        end
        FMADD: begin
            urnd_sel = fma_urnd_result;
            done_sel = fma_done;
            need_rnd_sel = 1'b1;
            round_only_sel = fma_round_only;
            mul_ovf_sel = fma_mul_ovf;
            mul_uf_sel = fma_mul_uf;
            mul_uround_out_sel = fma_mul_uround_out;
            // Use the rnd mode captured at acceptance time; rnd_i may have
            // changed by the cycle fma_done fires.
            rnd_sel = fma_busy_q ? fma_rnd_q : rnd_i;
        end
        F2F: begin
            done_sel = f2f_done;
            need_rnd_sel = f2f_need_rnd;
            if (f2f_need_rnd) begin
                urnd_sel = f2f_urnd_result;
            end else begin
                direct_result_sel = {{(64-FP_WIDTH){1'b0}}, f2f_direct_result};
                direct_flags_sel = f2f_direct_flags;
            end
        end
        F2I: begin
            done_sel = f2i_done;
            direct_result_sel = f2i_result_fp;
            direct_flags_sel = f2i_flags;
        end
        FCMP: begin
            done_sel = cmp_done;
            direct_result_sel = cmp_result_fp;
            direct_flags_sel = cmp_flags;
        end
        FCLASS: begin
            done_sel = class_done;
            direct_result_sel = class_result_fp;
            direct_flags_sel = '0;
        end
        FMIN, FMAX: begin
            done_sel = minmax_done;
            direct_result_sel = {{(64-FP_WIDTH){1'b0}}, minmax_result};
            direct_flags_sel = minmax_flags;
        end
        FSGNJ: begin
            done_sel = sgnj_done;
            direct_result_sel = {{(64-FP_WIDTH){1'b0}}, sgnj_result};
            direct_flags_sel = sgnj_flags;
        end
        default: begin
            done_sel = 1'b0;
        end
    endcase
end

/////////////////////////////////////////////////////////////////
// Regwall
/////////////////////////////////////////////////////////////////
uround_res_t urnd_q;
logic [63:0] direct_result_q;
status_t direct_flags_q;
logic done_q;
float_op_e op_q;
logic need_rnd_q;
logic round_only_q;
logic mul_ovf_q;
logic mul_uf_q;
logic mul_uround_out_q;
logic dz_q;
roundmode_e rnd_q;

always_ff @(posedge clk_i or negedge rst_i) begin
    if (!rst_i) begin
        urnd_q <= '0;
        direct_result_q <= '0;
        direct_flags_q <= '0;
        done_q <= 1'b0;
        op_q <= NO_FP_OP;
        need_rnd_q <= 1'b0;
        round_only_q <= 1'b0;
        mul_ovf_q <= 1'b0;
        mul_uf_q <= 1'b0;
        mul_uround_out_q <= 1'b0;
        dz_q <= 1'b0;
        rnd_q <= RNE;
    end else begin
        done_q <= done_sel;
        if (done_sel) begin
            urnd_q <= urnd_sel;
            direct_result_q <= direct_result_sel;
            direct_flags_q <= direct_flags_sel;
            op_q <= op_sel;
            need_rnd_q <= need_rnd_sel;
            round_only_q <= round_only_sel;
            mul_ovf_q <= mul_ovf_sel;
            mul_uf_q <= mul_uf_sel;
            mul_uround_out_q <= mul_uround_out_sel;
            dz_q <= dz_sel;
            rnd_q <= rnd_sel;
        end
    end
end

/////////////////////////////////////////////////////////////////
// Round
/////////////////////////////////////////////////////////////////
round_res_t rnd_result;
fp_rnd #(.FP_FORMAT(FP_FORMAT)) fp_rnd_inst
(
    .urnd_result_i(urnd_q),
    .rnd_i(rnd_q),
    .round_only(round_only_q),
    .mul_ovf(mul_ovf_q),
    .rnd_result_o(rnd_result)
);

/////////////////////////////////////////////////////////////////
// Output mux
/////////////////////////////////////////////////////////////////
logic fma_uf_fix;
logic fma_uf_fix1;
assign fma_uf_fix = (rnd_result.result.exp == '0) & (|urnd_q.rs);
assign fma_uf_fix1 = (urnd_q.u_result.exp == '0) &
                     (rnd_result.result.exp == {{EXP_WIDTH-1{1'b0}}, 1'b1}) &
                     mul_uround_out_q;

// ops whose output is an FP value (not integer / comparison bit / class mask)
logic result_is_fp;
fp_info_t raw_fp_info;
assign result_is_fp = need_rnd_q
                    | (op_q == FMIN) | (op_q == FMAX)
                    | (op_q == FSGNJ)
                    | (op_q == F2F);

logic [FP_WIDTH-1:0] raw_fp_result;
assign raw_fp_result = need_rnd_q ? rnd_result.result
                                  : direct_result_q[FP_WIDTH-1:0];

always_comb begin
    result_o = '0;
    flags_o = '0;
    valid_o = done_q;

    if (need_rnd_q) begin
        result_o = {{(64-FP_WIDTH){1'b0}}, rnd_result.result};
        flags_o = rnd_result.flags;
    end else begin
        result_o = direct_result_q;
        flags_o = direct_flags_q;
    end

    if (need_rnd_q && (op_q == FMADD)) begin
        flags_o.NV = rnd_result.flags.NV;
        flags_o.DZ = rnd_result.flags.DZ;
        flags_o.OF = rnd_result.flags.OF | mul_ovf_q;
        flags_o.UF = mul_uf_q ? (fma_uf_fix | fma_uf_fix1) : rnd_result.flags.UF;
        flags_o.NX = mul_uf_q ? (|urnd_q.rs) : (rnd_result.flags.NX | mul_ovf_q);
    end

    flags_o.DZ = flags_o.DZ | dz_q;

    // Canonical NaN (RISC-V): replace any NaN FP result with the format's
    // canonical quiet NaN.  Flags are left unchanged — the NV bit was already
    // set by the unit that produced the NaN.
    raw_fp_info = fp_info(raw_fp_result);
    if (RISCV_MODE && result_is_fp && raw_fp_info.is_nan)
        result_o = {{(64-FP_WIDTH){1'b0}}, QNAN_FP};
end

endmodule
