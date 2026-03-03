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


localparam int N = WIDTH / 2;
localparam int CNT_W = (N <= 1) ? 1 : $clog2(N);
localparam int REM_W = N + 2;

logic signed [REM_W-1:0] R;
logic signed [REM_W-1:0] R_int;
logic signed [REM_W-1:0] R_fix;
logic [N-1:0] Q;
logic [CNT_W-1:0] run_cnt;
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
logic [1:0] lut [N - 1:0];

genvar i;
generate
    for(i = 0; i < N; i=i+1) begin : gen_lut
        assign lut[i] = n_i[2*i+1:2*i];
    end
endgenerate


always_comb begin
  logic signed [REM_W+1:0] r_shifted;
  logic signed [REM_W+1:0] pair_ext;
  logic signed [REM_W+1:0] q_term;
  logic signed [REM_W+1:0] r_next_wide;

  r_shifted = $signed(R) <<< 2;
  pair_ext = $signed({{REM_W{1'b0}}, lut[run_cnt]});

  if (R >= 0) begin
    q_term = $signed({2'b00, Q, 2'b01});
    r_next_wide = r_shifted + pair_ext - q_term;
  end
  else begin
    q_term = $signed({2'b00, Q, 2'b11});
    r_next_wide = r_shifted + pair_ext + q_term;
  end

  R_int = r_next_wide[REM_W-1:0];
end

always_comb begin
  R_fix = R;
  if (R < 0)
    R_fix = R + $signed({1'b0, Q, 1'b1});
end

//run_cnt
always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i)
    run_cnt <= 'h0;
  else if(cur_state == IDLE)
    run_cnt <= CNT_W'(N - 1);
  else if(cur_state == RUN && run_cnt != '0)
    run_cnt <= run_cnt - 1'b1;
  else if(cur_state == DONE)
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
      Q <= (R_int < 0)? (Q << 1) : ((Q << 1) | {{(N-1){1'b0}}, 1'b1});
  end
end
//output
always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i)
    q_o <= 'h0;
  else if(cur_state == DONE)
    q_o <= {{(WIDTH-N){1'b0}}, Q};
end

always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i)
    r_o <= 'h0;
  else if(cur_state == DONE)
    r_o <= {{(WIDTH-REM_W){1'b0}}, R_fix};
end

always_ff @( posedge clk_i or negedge reset_i ) begin
  if(!reset_i)
    valid_o <= 'h0;
  else 
    valid_o <= (cur_state == DONE);
end


endmodule
