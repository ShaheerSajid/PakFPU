module int_div
#(
  parameter WIDTH = 32
)
(
  input clk_i,
  input reset_i,
  input start_i,
  input [WIDTH-1:0] n_i,
  input [WIDTH-1:0] d_i,

  output logic [WIDTH-1:0] q_o,
  output logic [WIDTH-1:0] r_o,
  output logic valid_o
);

/*
Non-restoring binary division (1 bit per cycle).
  R := N
  D := D << WIDTH        -- align divisor to upper half of double-width registers
  for i = WIDTH-1 .. 0:
    if R >= 0:  q(i) = +1, R = 2R - D
    else:       q(i) = -1, R = 2R + D
  Convert redundant quotient to two's complement.
  If R < 0: Q -= 1, R += D  (remainder correction)
Latency: WIDTH cycles (RUN state) + 1 cycle (DONE state).
Source: https://en.wikipedia.org/wiki/Division_algorithm
*/

logic [2*WIDTH-1:0] R;
logic [2*WIDTH-1:0] D;
logic [WIDTH-1:0]   Q;
logic [$clog2(WIDTH):0] run_cnt;

//////////////////////
// State machine
//////////////////////
typedef enum logic [1:0] {IDLE, RUN, DONE} state;
state cur_state, nxt_state;

always_comb begin
  case (cur_state)
    IDLE:    nxt_state = start_i ? RUN : IDLE;
    RUN:     nxt_state = (run_cnt == 0) ? DONE : RUN;
    DONE:    nxt_state = IDLE;
    default: nxt_state = IDLE;
  endcase
end

always_ff @(posedge clk_i or negedge reset_i) begin
  if (!reset_i)
    cur_state <= IDLE;
  else
    cur_state <= nxt_state;
end

//////////////////////
// Datapath registers
//////////////////////
always_ff @(posedge clk_i or negedge reset_i) begin
  if (!reset_i)
    run_cnt <= '0;
  else if (cur_state == IDLE)
    run_cnt <= WIDTH - 1;
  else if (cur_state == RUN)
    run_cnt <= run_cnt - 1'b1;
  else
    run_cnt <= '0;
end

always_ff @(posedge clk_i or negedge reset_i) begin
  if (!reset_i) begin
    R <= '0;
    Q <= '0;
    D <= '0;
  end else if (cur_state == IDLE) begin
    R <= {{WIDTH{1'b0}}, n_i};      // zero-extend numerator into lower half
    D <= {d_i, {WIDTH{1'b0}}};      // align divisor into upper half
  end else if (cur_state == RUN) begin
    if (~R[2*WIDTH-1]) begin
      Q[run_cnt] <= 1'b1;
      R          <= (R << 1) - D;
    end else begin
      Q[run_cnt] <= 1'b0;
      R          <= (R << 1) + D;
    end
  end
end

//////////////////////
// Output / correction
//////////////////////
logic [2*WIDTH-1:0] R_fix;
assign R_fix = $signed(R) + $signed(D);

logic [WIDTH-1:0] Q_fix;
assign Q_fix = Q - (~Q);

always_ff @(posedge clk_i or negedge reset_i) begin
  if (!reset_i)
    q_o <= '0;
  else if (cur_state == DONE)
    q_o <= R[2*WIDTH-1] ? Q_fix - 1'b1 : Q_fix;
end

always_ff @(posedge clk_i or negedge reset_i) begin
  if (!reset_i)
    r_o <= '0;
  else if (cur_state == DONE)
    r_o <= R[2*WIDTH-1] ? R_fix[2*WIDTH-1 -: WIDTH] : R[2*WIDTH-1 -: WIDTH];
end

always_ff @(posedge clk_i or negedge reset_i) begin
  if (!reset_i)
    valid_o <= '0;
  else
    valid_o <= (cur_state == DONE);
end

endmodule
