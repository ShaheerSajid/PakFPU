module recip (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        start,         // Start pulse initiates computation
    input  logic [63:0] X_in,          // Q9.55 initial guess
    input  logic [63:0] D_in,          // Q9.55 divisor
    output logic [63:0] reciprocal,    // Q9.55 reciprocal
    output logic        done           // Result valid pulse
);

// Fixed-point parameters
localparam int Q_FRAC = 55;
localparam int Q_INT  = 9;
localparam int Q_WIDTH = 64;

// Iteration control
logic [1:0] iteration;  // 0-3 (4 iterations)
logic [63:0] X, D;

// 128-bit multiplication results
logic [127:0] x_squared;
logic [127:0] dx_squared;

// FSM logic
enum logic {IDLE, BUSY} state;

always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        state       <= IDLE;
        iteration   <= '0;
        X           <= '0;
        D           <= '0;
        reciprocal  <= '0;
        done        <= '0;
    end else begin
        done <= '0;  // Default done signal

        case (state)
            IDLE: begin
                if (start) begin
                    X     <= X_in;
                    D     <= D_in;
                    state <= BUSY;
                    iteration <= 0;
                end
            end

            BUSY: begin
                // Pipeline Newton-Raphson: X_{n+1} = 2X_n - D*X_n²
                x_squared = X * X;
                dx_squared = D * x_squared[118:55];  // Align decimal points

                // Update calculation
                X <= (X << 1) - dx_squared[118:55];  // Maintain Q9.55 format
                iteration <= iteration + 1;

                if (iteration == 3) begin
                    reciprocal <= (X << 1) - dx_squared[118:55];
                    done       <= 1'b1;
                    state      <= IDLE;
                end
            end
        endcase
    end
end

endmodule



// module recip (
//     input wire clk,
//     input wire reset_n,
//     input wire start,          // Start signal (pulse to begin)
//     input wire [63:0] X_in,    // Q9.23 initial guess
//     input wire [63:0] D_in,    // Q9.23 divisor
//     output reg [63:0] reciprocal,  // Q9.23 reciprocal
//     output reg done           // Result valid strobe
// );

// // Q9.23 format parameters
// localparam Q_FRAC = 55;
// localparam Q_INT = 9;
// localparam Q_WIDTH = 64;

// // Iteration counter
// reg [2:0] iteration;

// // Internal registers
// reg [Q_WIDTH-1:0] X;
// reg [Q_WIDTH-1:0] D;

// // Multiplier temporary storage
// reg [Q_WIDTH*2-1:0] product;

// always @(posedge clk or negedge reset_n) begin
//     if (!reset_n) begin
//         X <= X_in;
//         D <= D_in;
//         reciprocal <= 0;
//         done <= 0;
//         iteration <= 0;
//     end else begin
//         if (start && iteration < 4) begin
//             // Newton-Raphson iteration: X = 2X - D*X²
//             product = X * X;  // X² (Q18.46)
//             product = product >> Q_FRAC;  // Convert back to Q9.23
            
//             // Calculate D*X²
//             product = D * product[Q_WIDTH-1:0];  // Q9.23 * Q9.23
//             product = product >> Q_FRAC;  // Convert back to Q9.23

//             // Calculate 2X - D*X²
//             reciprocal <= (X << 1) - product[Q_WIDTH-1:0];
            
//             // Update X for next iteration
//             X <= (X << 1) - product[Q_WIDTH-1:0];
//             iteration <= iteration + 1;
//         end
        
//         // Signal completion after 4 iterations
//         done <= (iteration == 4);
//     end
// end

// endmodule
