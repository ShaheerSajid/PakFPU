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
  output logic valid_o
);

/*
R := N
D := D << n            -- R and D need twice the word width of N and Q
for i = n − 1 .. 0 do  -- for example 31..0 for 32 bits
  if R >= 0 then
    q(i) := +1
    R := 2 * R − D
  else
    q(i) := −1
    R := 2 * R + D
  end if
end

Q := Q − bit.bnot(Q)

if R < 0 then
  Q := Q − 1
  R := R + D  -- Needed only if the remainder is of interest.
end if
-- Note: N=numerator, D=denominator, n=#bits, R=partial remainder, q(i)=bit #i of quotient.
Source: https://en.wikipedia.org/wiki/Division_algorithm
*/


logic [2*WIDTH - 1:0] R;
logic [2*WIDTH - 1:0] D;
logic [WIDTH - 1:0] Q;
logic [$clog2(WIDTH):0] n;
logic [$clog2(WIDTH):0] run_cnt;


logic [WIDTH - 1:0] n_internal;
logic [WIDTH - 1:0] d_internal;

assign n_internal = n_i;
assign d_internal = d_i;

// calculate n-bits
assign n = WIDTH;
//////////////////////
//state machine
//////////////////////
typedef enum logic[1:0] {IDLE, RUN, DONE} state;
state cur_state, nxt_state;

//next state logic
always_comb begin
  case(cur_state)
    IDLE: nxt_state = start_i? RUN : IDLE;
    RUN:  nxt_state = (run_cnt == 0)? DONE : RUN;
    DONE: nxt_state = IDLE;
    default: nxt_state = IDLE;
  endcase
end
//state hopper
always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i)
    cur_state <= IDLE;
  else
    cur_state <= nxt_state;
end
//////////////////////
//Registers
//////////////////////
//run_cnt
always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i)
    run_cnt <= 'h0;
  else if(cur_state == IDLE)
    run_cnt <= n - 1;
  else if(cur_state == RUN)
    run_cnt <= run_cnt - 1'b1;
  else 
    run_cnt <= 'h0;
end
//R, D, Q
always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i) begin
    R <= 'h0;
    Q <= 'h0;
    D <= 'h0;
  end
  else if(cur_state == IDLE) begin
    R <= n_internal;
    D <= d_internal << n;
  end
  else if(cur_state == RUN) begin
    if(~R[2*WIDTH-1]) begin
      Q[run_cnt]  <= 1'b1;
      R           <= (R << 1) - D;
    end
    else begin
      Q[run_cnt]  <= 1'b0;
      R           <= (R << 1) + D;
    end
  end
end
//output
logic [WIDTH - 1:0] Q_fix;
assign Q_fix = Q - (~Q);

always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i)
    q_o <= 'h0;
  else if(cur_state == DONE)
    q_o     <= (R[2*WIDTH-1])? Q_fix - 1'b1 : Q_fix;
end

always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i)
    valid_o = 'h0;
  else 
    valid_o = (cur_state == DONE);
end


endmodule