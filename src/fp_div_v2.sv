module fp_div (
    input wire clk,
    input wire reset_n,
    input wire start,       // Start signal (pulse to begin)
    output reg done,         // Result valid strobe
    input  wire [31:0] A,   // 32-bit floating-point input A
    input  wire [31:0] B,   // 32-bit floating-point input B
    output reg  [31:0] R    // 32-bit floating-point result
);

    // // Express D as M × 2e where 1 ≤ M < 2 (standard floating point representation)
    // D' := D / 2^(e+1)  // scale between 0.5 and 1, can be performed with bit shift / exponent subtraction
    // N' := N / 2^(e+1)
    // X := 48/17 - 32/17 * D'  // precompute constants with same precision as D
    // repeat 
    //     // The following number of iterations is based on the logarithm calculation, precompute P based on fixed value
    //     repeat_count = ceil(log2((P+1) / log2(17)))
    //     // Iterative refinement of X
    //     X := X + X * (1 - D' * X)
    // end
    // Return N' * X

    // Constants
    localparam C1_fixed = 32'h01696969;  // Precompute C1 / 17 as a fixed-point value
    localparam C2_fixed = 32'h00f0f0f1;  // Precompute C2 / 17 as a fixed-point value
    localparam EXP_BIAS = 8'd127; // For IEEE 754 single-precision format

    // Internal signals
    reg [31:0] A_mantissa, B_mantissa;
    reg [7:0] A_exponent, B_exponent;
    reg A_sign, B_sign;
    reg [31:0] N_prime, D_prime;
    reg [63:0] X0;
    wire [31:0] reciprocal;
    reg [7:0] uexp_result;
    reg [7:0] exp_result;
    reg [63:0] umant_res;
    reg [63:0] shift_mant_res;
    reg [22:0] mant_res;

    // Extract the sign, exponent, and mantissa of A and B
    always @(*) begin
        A_sign       = A[31];
        B_sign       = B[31];
        A_exponent   = A[30:23];
        B_exponent   = B[30:23];
        A_mantissa   = {1'b1, A[22:0]};  // Add implicit leading 1 to mantissa
        B_mantissa   = {1'b1, B[22:0]};  // Add implicit leading 1 to mantissa
    end

    // Step 1: Normalize and scale D and N (D' and N')

    function automatic logic is_float_in_range(input [31:0] float_num);
        logic        sign;
        logic [7:0]  exponent;
        logic [22:0] mantissa;
        begin
            // Extract IEEE 754 components
            sign     = float_num[31];
            exponent = float_num[30:23];
            mantissa = float_num[22:0];

            // Range check logic
            is_float_in_range = (sign == 1'b0) &&                  // Positive
                            ((exponent == 8'h7E) ||              // 0.5 ≤ X < 1.0
                            (exponent == 8'h7F && mantissa == 0)); // Exactly 1.0
        end
    endfunction

    always @(*) begin
        N_prime = is_float_in_range(A)? A_mantissa : A_mantissa >> 1;
        D_prime = is_float_in_range(B)? B_mantissa : B_mantissa >> 1;
    end

    // Step 2: Precompute the constant X
    always @(*) begin
        // Calculate initial X using D'
        X0 = $signed({8'd0,C1_fixed,23'd0}) - ($signed(C2_fixed) * $signed(D_prime));
    end

    // Step 3: Perform iterations to refine X
    wire [63:0] recip_64;

    recip #(
        .Q_INT      (9),
        .Q_FRAC     (23),
        .ITERATIONS (3)
    ) recip_inst (
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .X_in(X0[54:23]),
        .D_in(D_prime),
        .reciprocal(recip_64),
        .done(done)
    );
    assign reciprocal = recip_64[32:4];
    // Step 4: Final result
    assign uexp_result = A_exponent - B_exponent + EXP_BIAS;
    assign umant_res = A_mantissa * {reciprocal,4'b0};

    wire [5:0] shamt;
    lzc #(.WIDTH(48)) lzc_inst
    (
        .a_i(umant_res[47:0]),
        .cnt_o(shamt),
        .zero_o()
    );

        
    assign shift_mant_res = umant_res[48]? umant_res >> 1 : umant_res << shamt;
    assign mant_res = shift_mant_res[46-:23];
    assign exp_result = umant_res[48]? uexp_result : uexp_result - shamt;
    assign R = {A_sign ^ B_sign, exp_result[7:0], mant_res};

endmodule