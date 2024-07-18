module int_sqrt
#(
  parameter WIDTH = 24
)
(
  input clk_i,
  input reset_i,
  input start_i,
  input [WIDTH-1:0] n_i, 
  
  output logic [WIDTH-1:0] q_o,
  output logic [WIDTH-1:0] r_o, 
  output logic valid_o
);


logic [(WIDTH/2):0] R;
logic [(WIDTH/2) - 1:0] Q;
logic [$clog2(WIDTH/2):0] n;
logic [$clog2(WIDTH/2):0] run_cnt;

// calculate n-bits
assign n = WIDTH / 2;
//////////////////////
//state machine
//////////////////////
typedef enum logic[1:0] {IDLE, RUN, DONE} state;
state cur_state, nxt_state;

//next state logic
always_comb begin
  case(cur_state)
    IDLE: nxt_state = start_i? RUN : IDLE;
    RUN:  nxt_state = (run_cnt == 3)? DONE : RUN;
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
logic [1:0] lut [(WIDTH/2) - 1:0];
logic [(WIDTH/2):0] R_int;

genvar i;
generate
    for(i = (WIDTH/2)-1; i >= 0; i=i-1)
     assign lut[i] = n_i[2*i+1:2*i];
endgenerate


always_comb
    if(~R[(WIDTH/2)])
      R_int = ((R << 2) | lut[run_cnt]) - ((Q << 2) | 2'b01);
    else
      R_int = ((R << 2) | lut[run_cnt]) + ((Q << 2) | 2'b11);
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
  end
  else if(cur_state == IDLE) begin
    R <= 'h0;
    Q <= 'h0;
  end
  else if(cur_state == RUN) begin
      R <= R_int;
      Q <= (R_int[(WIDTH/2)])? (Q << 1) : (Q << 1) | 1;
  end
end
//output
logic [2*WIDTH - 1:0] R_fix;

always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i)
    q_o <= 'h0;
  else if(cur_state == DONE)
    q_o <= Q;
end

always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i)
    r_o <= 'h0;
  else if(cur_state == DONE)
    r_o     <= (R[2*WIDTH-1])? R_fix[2*WIDTH-1 -: WIDTH] : R[2*WIDTH-1 -: WIDTH];
end

always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i)
    valid_o = 'h0;
  else 
    valid_o = (cur_state == DONE);
end


endmodule