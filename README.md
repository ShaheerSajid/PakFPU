# Pakfpu

A FPU developed for the open-source community. The FPU is IEEE-754 compliant and verified using Berkely TestFloat. Pakfpu is implemented in systemverilog and is fully paramterizable supporting single, double and quad precision. 32 and 64bit integer formats are also supported.

## Operations
* Addition/ Subtraction
* Multiplication
* Fused multiply and add
* Division
* Square root (in-progress)
* Min/Max
* Comparison
* Sign Injection
* Conversion to different FP format
* Conversion between FP format and integers
* Classification

## Rounding Modes
* RNE: round nearest (to even)
* RTZ: round to zero
* RDN: round down
* RUP: round up
* RMM: round nearest (to max magnitude)
* DYN: dynamic

The latencies of the operations are shown below:
|Operation|Latency|
|---|---|
|Add/Sub/Mul| 1  |
|Convert| 1  |
|Compare| 1  |
|Sign Injection| 1  |
|Fused| 2  |
|Div| 50 (Optimization in-progress)  |
|Sqrt| 27  |

The area and fmax (de1soc fpga and TSMC 65nm) are listed below:
|Operation|Area|Frequency|
|---|---|---|
|   |   |   |
|   |   |   |
|   |   |   |

## Usage and Integration

The following code snippet shows the top level ports for interfacing pakfpu. By specifying FP64 the user can instantiate a double precision fpu.
```
module fp_top
#(
    parameter fp_format_e FP_FORMAT = FP32,
    parameter fp_format_e INT_FORMAT = INT32,

    localparam int unsigned FP_WIDTH = fp_width(FP_FORMAT),
    localparam int unsigned EXP_WIDTH = exp_bits(FP_FORMAT),
    localparam int unsigned MANT_WIDTH = man_bits(FP_FORMAT),
)
(
    input clk_i,
    input rst_i,

    input start_i,
    output ready_o,

    input [FP_WIDTH-1:0] a_i,
    input [FP_WIDTH-1:0] b_i,
    input [FP_WIDTH-1:0] c_i,

    input roundmode_e rnd_i,

    input float_op_e op_i,
    input [1:0] op_modify_i,

    output [FP_WIDTH-1:0] result_o,
    output valid_o,
    output status_t flags_o
);
```

## Contribute
