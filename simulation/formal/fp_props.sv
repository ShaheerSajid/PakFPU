// fp_props.sv — Formal properties for PakFPU
//
// Yosys-compatible: no SVA temporal operators (|-> |=> ##).
// Uses always@(posedge) + immediate assert() + $past() + pending-state regs.
// Bound to fp_top via bind in fp_top.sby (FP_FORMAT=0, RISCV_MODE=1).

`default_nettype none

module fp_props
#(
    parameter integer FP_FORMAT  = 0,   // 0=FP32, 2=FP64
    parameter integer INT_FORMAT = 0,
    parameter logic   RISCV_MODE = 1'b0
)
(
    input logic          clk_i,
    input logic          rst_i,

    input logic          start_i,
    input logic          ready_o,
    input logic [63:0]   a_i,
    input logic [63:0]   b_i,
    input logic [63:0]   c_i,
    input logic [2:0]    rnd_i,
    input logic [3:0]    op_i,
    input logic [1:0]    op_modify_i,

    input logic [63:0]   result_o,
    input logic          valid_o,
    input logic [4:0]    flags_o
);

// ---------------------------------------------------------------------------
// Format geometry
// ---------------------------------------------------------------------------
localparam integer FP_WIDTH   = (FP_FORMAT == 2) ? 64 : 32;
localparam integer EXP_WIDTH  = (FP_FORMAT == 2) ? 11 : 8;
localparam integer MANT_WIDTH = (FP_FORMAT == 2) ? 52 : 23;

localparam [3:0] OP_FADD   = 4'd0;
localparam [3:0] OP_FMUL   = 4'd1;
localparam [3:0] OP_FDIV   = 4'd2;
localparam [3:0] OP_F2F    = 4'd5;
localparam [3:0] OP_FCMP   = 4'd6;
localparam [3:0] OP_FCLASS = 4'd7;
localparam [3:0] OP_FMIN   = 4'd8;
localparam [3:0] OP_FMAX   = 4'd9;
localparam [3:0] OP_FSGNJ  = 4'd10;
localparam [3:0] OP_FMADD  = 4'd11;

localparam integer NV = 4;  // flags_o bit index
localparam integer DZ = 3;

localparam [FP_WIDTH-1:0] QNAN_FP =
    {1'b0, {EXP_WIDTH{1'b1}}, 1'b1, {(MANT_WIDTH-1){1'b0}}};

// ---------------------------------------------------------------------------
// Helpers — function-name assignment (no 'return', no 'inside')
// ---------------------------------------------------------------------------
function automatic logic fp_is_nan(input logic [FP_WIDTH-1:0] v);
    fp_is_nan = (v[FP_WIDTH-2 -: EXP_WIDTH] == {EXP_WIDTH{1'b1}})
              & (v[MANT_WIDTH-1:0] != {MANT_WIDTH{1'b0}});
endfunction

function automatic logic fp_is_snan(input logic [FP_WIDTH-1:0] v);
    fp_is_snan = fp_is_nan(v) & ~v[MANT_WIDTH-1];
endfunction

function automatic logic fp_is_inf(input logic [FP_WIDTH-1:0] v);
    fp_is_inf = (v[FP_WIDTH-2 -: EXP_WIDTH] == {EXP_WIDTH{1'b1}})
              & (v[MANT_WIDTH-1:0] == {MANT_WIDTH{1'b0}});
endfunction

function automatic logic fp_is_zero(input logic [FP_WIDTH-1:0] v);
    fp_is_zero = (v[FP_WIDTH-2:0] == {(FP_WIDTH-1){1'b0}});
endfunction

wire [FP_WIDTH-1:0] a_fp   = a_i[FP_WIDTH-1:0];
wire [FP_WIDTH-1:0] b_fp   = b_i[FP_WIDTH-1:0];
wire [FP_WIDTH-1:0] res_fp = result_o[FP_WIDTH-1:0];
wire accept = start_i & ready_o;

// Op-category wires (no 'inside' keyword — explicit OR chains)
wire op_is_arith  = (op_i == OP_FADD || op_i == OP_FMUL || op_i == OP_FDIV ||
                     op_i == OP_FMADD || op_i == OP_FCMP ||
                     op_i == OP_FMIN  || op_i == OP_FMAX);
wire op_is_fp_out = (op_i == OP_FADD || op_i == OP_FMUL || op_i == OP_FDIV ||
                     op_i == OP_FMADD || op_i == OP_FMIN || op_i == OP_FMAX ||
                     op_i == OP_FSGNJ || op_i == OP_F2F);
// FMIN/FMAX excluded: RISC-V defines FMIN/FMAX(x, qNaN) = x (not qNaN),
// so a NaN-boxed input (treated as canonical qNaN) does not produce qNaN result.
wire op_is_nanbox = (op_i == OP_FADD || op_i == OP_FMUL || op_i == OP_FDIV ||
                     op_i == OP_FMADD);

// In FP32+RISCV mode a NaN-boxed input is treated as canonical qNaN, NOT sNaN.
// For FP32 (FP_FORMAT==0), validity requires upper 32 bits == 0xFFFFFFFF.
// For FP64 (FP_FORMAT==2), full 64 bits are used so boxing always "valid".
wire a_nanbox_valid = (FP_FORMAT != 0) || (a_i[63:32] == 32'hFFFF_FFFF);
wire b_nanbox_valid = (FP_FORMAT != 0) || (b_i[63:32] == 32'hFFFF_FFFF);

// sNaN guard: only meaningful when NaN-boxing is intact
wire a_is_boxed_snan = fp_is_snan(a_fp) && a_nanbox_valid;
wire b_is_boxed_snan = fp_is_snan(b_fp) && b_nanbox_valid;

// inf/zero guards: only meaningful when NaN-boxing is intact
wire a_is_valid_inf  = fp_is_inf(a_fp)  && a_nanbox_valid;
wire b_is_valid_inf  = fp_is_inf(b_fp)  && b_nanbox_valid;
wire a_is_valid_zero = fp_is_zero(a_fp) && a_nanbox_valid;
wire b_is_valid_zero = fp_is_zero(b_fp) && b_nanbox_valid;

// ---------------------------------------------------------------------------
// Protocol assumption: the caller respects the ready_o/valid_o handshake.
// While valid_o is asserted the caller must not start a new operation.
// This is required for valid_o to be a single-cycle pulse (P8) and
// matches the testbench's "issue start, wait for valid" protocol.
// ---------------------------------------------------------------------------
always @(posedge clk_i) begin
    if (rst_i && f_past_valid && valid_o)
        assume(!accept);
end

// ---------------------------------------------------------------------------
// f_past_valid — suppress assertions on first cycle
// ---------------------------------------------------------------------------
reg f_past_valid = 1'b0;
always @(posedge clk_i) f_past_valid <= 1'b1;

// ---------------------------------------------------------------------------
// Reset constraints
//   1. Force rst_i=0 at time-0 ($initstate) AND at the first posedge clock,
//      so all of fp_top's flip-flops start from the reset state.
//   2. With prep -nordff, Yosys leaves the fp_props pending registers with
//      unconstrained initial values ($anyinit).  Explicitly constrain them
//      to 0 at $initstate to prevent the solver from pre-setting them and
//      triggering spurious assertion failures.
// ---------------------------------------------------------------------------
always @(*) if ($initstate) begin
    assume(!rst_i);
    assume(!f_past_valid);
    assume(!f_p1); assume(!f_p2); assume(!f_p3); assume(!f_p4);
    assume(!f_p5); assume(!f_p6a); assume(!f_p6b); assume(!f_p7);
end
always @(posedge clk_i) if (!f_past_valid) assume(!rst_i);

// ---------------------------------------------------------------------------
// Pending-operation trackers
// PakFPU is non-pipelined: ready_o deasserts after accept, so only one
// in-flight operation exists at a time.
// ---------------------------------------------------------------------------

// P2: fp-output op pending — captures at accept time so op_i is not sampled
// at valid_o time (op_i could have changed if a new op was queued).
reg f_p2 = 1'b0;
always @(posedge clk_i) begin
    if (!rst_i)                               f_p2 <= 1'b0;
    else if (accept && op_is_fp_out)          f_p2 <= 1'b1;
    else if (valid_o)                         f_p2 <= 1'b0;
end

// P1: sNaN input pending
reg f_p1 = 1'b0;
always @(posedge clk_i) begin
    if (!rst_i)                                                    f_p1 <= 1'b0;
    else if (accept && op_is_arith &&
             (a_is_boxed_snan || b_is_boxed_snan))                 f_p1 <= 1'b1;
    else if (valid_o)                                              f_p1 <= 1'b0;
end

// P3: FSGNJ pending
reg f_p3 = 1'b0;
always @(posedge clk_i) begin
    if (!rst_i)                              f_p3 <= 1'b0;
    else if (accept && op_i == OP_FSGNJ)     f_p3 <= 1'b1;
    else if (valid_o)                        f_p3 <= 1'b0;
end

// P4: FCLASS pending
reg f_p4 = 1'b0;
always @(posedge clk_i) begin
    if (!rst_i)                              f_p4 <= 1'b0;
    else if (accept && op_i == OP_FCLASS)    f_p4 <= 1'b1;
    else if (valid_o)                        f_p4 <= 1'b0;
end

// P5: FDIV divide-by-zero pending (finite / 0, no modify)
// Both operands must have valid NaN-boxing; otherwise the RTL treats them as
// canonical qNaN and the result is qNaN, not the divide-by-zero case.
reg f_p5 = 1'b0;
always @(posedge clk_i) begin
    if (!rst_i)                                                     f_p5 <= 1'b0;
    else if (accept && op_i == OP_FDIV && ~op_modify_i[0] &&
             a_nanbox_valid && b_nanbox_valid &&
             ~fp_is_nan(a_fp) && ~fp_is_nan(b_fp) &&
             ~fp_is_inf(a_fp) && fp_is_zero(b_fp))                 f_p5 <= 1'b1;
    else if (valid_o)                                               f_p5 <= 1'b0;
end

// P6a: NaN-box violation on operand a
reg f_p6a = 1'b0;
always @(posedge clk_i) begin
    if (!rst_i)                                                     f_p6a <= 1'b0;
    else if (accept && op_is_nanbox && a_i[63:32] != 32'hFFFF_FFFF) f_p6a <= 1'b1;
    else if (valid_o)                                               f_p6a <= 1'b0;
end

// P6b: NaN-box violation on operand b
reg f_p6b = 1'b0;
always @(posedge clk_i) begin
    if (!rst_i)                                                     f_p6b <= 1'b0;
    else if (accept && op_is_nanbox && b_i[63:32] != 32'hFFFF_FFFF) f_p6b <= 1'b1;
    else if (valid_o)                                               f_p6b <= 1'b0;
end

// P7: ±Inf × ±0 pending — NaN-boxing must be valid on both operands so the
// RTL sees the actual Inf/zero values, not a substituted canonical qNaN.
reg f_p7 = 1'b0;
always @(posedge clk_i) begin
    if (!rst_i)                                                     f_p7 <= 1'b0;
    else if (accept && op_i == OP_FMUL &&
             ((a_is_valid_inf && b_is_valid_zero) ||
              (a_is_valid_zero && b_is_valid_inf)))                 f_p7 <= 1'b1;
    else if (valid_o)                                               f_p7 <= 1'b0;
end

// ---------------------------------------------------------------------------
// Assertions
// ---------------------------------------------------------------------------
always @(posedge clk_i) begin
    if (rst_i && f_past_valid) begin

        // P1: sNaN input always raises NV
        if (f_p1 && valid_o)
            assert(flags_o[NV]);

        // P2: NaN result == canonical qNaN (RISC-V)
        // Use f_p2 (set at accept time) not op_is_fp_out (changes with op_i).
        if (RISCV_MODE) begin
            if (f_p2 && valid_o && fp_is_nan(res_fp))
                assert(res_fp == QNAN_FP);
        end

        // P3: FSGNJ never raises flags
        if (f_p3 && valid_o)
            assert(flags_o == 5'b0);

        // P4: FCLASS never raises flags
        if (f_p4 && valid_o)
            assert(flags_o == 5'b0);

        // P5: FDIV by zero raises DZ and not NV
        if (f_p5 && valid_o) begin
            assert(flags_o[DZ]);
            assert(!flags_o[NV]);
        end

        // P6: NaN-box violation → canonical qNaN (RISC-V only)
        // Only covers FADD/FMUL/FDIV/FMADD (see op_is_nanbox).
        // FMIN/FMAX are excluded: FMIN(x, qNaN) = x per RISC-V spec.
        // NV is NOT required: a NaN-boxed value is treated as canonical qNaN,
        // and qNaN inputs do not raise the Invalid flag.
        if (RISCV_MODE) begin
            if (f_p6a && valid_o)
                assert(res_fp == QNAN_FP);
            if (f_p6b && valid_o)
                assert(res_fp == QNAN_FP);
        end

        // P7: ±Inf × ±0 raises NV
        if (f_p7 && valid_o)
            assert(flags_o[NV]);

        // P8: valid_o is a single-cycle pulse
        // Guard with $past(rst_i) to avoid cross-reset-boundary false positives.
        if ($past(rst_i) && $past(valid_o))
            assert(!valid_o);

        // P9: ready_o deasserts the cycle after an FDIV is accepted
        if ($past(rst_i) && $past(accept) && $past(op_i == OP_FDIV))
            assert(!ready_o);

    end
end

// ---------------------------------------------------------------------------
// Cover points
// ---------------------------------------------------------------------------
C_add_normal:   cover property (
    accept && (op_i == OP_FADD)
    && !fp_is_nan(a_fp) && !fp_is_inf(a_fp)
    && !fp_is_nan(b_fp) && !fp_is_inf(b_fp));
C_mul_inf_zero: cover property (
    accept && (op_i == OP_FMUL) && fp_is_inf(a_fp) && fp_is_zero(b_fp));
C_div_by_zero:  cover property (
    accept && (op_i == OP_FDIV) && fp_is_zero(b_fp));
C_snan_input:   cover property (accept && fp_is_snan(a_fp));

endmodule
