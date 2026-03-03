module recip #(
    parameter int Q_INT    = 9,      // Integer bits (including sign)
    parameter int Q_FRAC   = 55,     // Fractional bits
    parameter int ITERATIONS = 4,    // Number of Newton-Raphson iterations
    parameter int Q_WIDTH  = Q_INT + Q_FRAC  // Total bit width
) (
    input  logic                clk,
    input  logic                reset_n,
    input  logic                start,         // Start pulse
    input  logic [Q_WIDTH-1:0]  X_in,          // Initial guess (Qm.n)
    input  logic [Q_WIDTH-1:0]  D_in,          // Divisor (Qm.n)
    output logic [Q_WIDTH-1:0]  reciprocal,    // Reciprocal result
    output logic                done           // Result valid pulse
);

// -------------------------------------------------------------------------
// Local Parameters and Signals
// -------------------------------------------------------------------------
localparam int PROD_WIDTH = 2*Q_WIDTH;  // Full multiplication width

// Iteration control
logic [$clog2(ITERATIONS)-1:0] iteration;  // Dynamic width based on ITERATIONS
logic [Q_WIDTH-1:0] X, D;

// Multiplication results (full precision)
logic [PROD_WIDTH-1:0] x_squared;
logic [PROD_WIDTH-1:0] dx_squared;

// FSM states
typedef enum logic {IDLE, BUSY} state_t;
state_t state;

// -------------------------------------------------------------------------
// Newton-Raphson Core Logic
// -------------------------------------------------------------------------
always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        state       <= IDLE;
        iteration   <= '0;
        X           <= '0;
        D           <= '0;
        reciprocal  <= '0;
        done        <= '0;
    end else begin
        done <= '0;  // Single-cycle pulse

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
                // Pipeline calculations
                x_squared  = X * X;  // Full precision multiply
                dx_squared = D * x_squared[PROD_WIDTH-1:Q_FRAC];  // Align decimal

                // X_{n+1} = 2X_n - D*X_n² (maintain Qm.n format)
                X <= (X << 1) - dx_squared[PROD_WIDTH-1:Q_FRAC];
                iteration <= iteration + 1;

                if (iteration == ITERATIONS-1) begin
                    reciprocal <= (X << 1) - dx_squared[PROD_WIDTH-1:Q_FRAC];
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
