# Pakfpu

A FPU developed for the open-source community. The FPU is IEEE-754 compliant and verified using Berkeley TestFloat. Pakfpu is implemented in SystemVerilog and is fully parameterizable, supporting single and double precision. 32 and 64-bit integer formats are also supported.

> **Note:** `FP48` is an internal format used only by the FMA pipeline to preserve mantissa width during intermediate computation. It is not a user-facing precision level.

## Operations
* Addition / Subtraction
* Multiplication
* Fused Multiply-Add
* Division
* Square Root
* Min / Max
* Comparison
* Sign Injection
* Conversion between FP formats
* Conversion between FP and integers
* Classification

## Rounding Modes
* RNE: round nearest (to even)
* RTZ: round to zero
* RDN: round down
* RUP: round up
* RMM: round nearest (to max magnitude)
* DYN: dynamic (selected at runtime via `rnd_i`)

## Latency

All latencies are in clock cycles from assertion of `start_i` to assertion of `valid_o`.

| Operation     | FP32 | FP64 | Notes |
|---------------|------|------|-------|
| Add / Sub     | 2    | 2    | 1 compute + 1 regwall/round |
| Multiply      | 2    | 2    | 1 compute + 1 regwall/round |
| Fused (FMA)   | 3    | 3    | 2 compute + 1 regwall/round |
| Convert       | 2    | 2    | |
| Compare       | 2    | 2    | |
| Sign Injection| 2    | 2    | |
| Square Root   | ~29  | ~57  | digit-recurrence, WIDTH/2 iterations |
| **Div**       | **~52** | **~110** | digit-recurrence, 1 bit/cycle — optimization in progress (target: radix-4 SRT, ~26 / ~55 cycles) |

## Area and Frequency

Synthesized with Quartus Prime 24.1std for Cyclone V (5CSEMA5F31C6, speed grade 6).
Fmax is the achievable frequency derived from worst-case slow-corner setup slack at 50 MHz.

| Configuration | ALMs | Registers | DSP Blocks | Fmax (Cyclone V) |
|---------------|------|-----------|------------|-----------------|
| FP32, DE1-SoC (Cyclone V) | 2,987 (9%) | 702 | 2 | ~46.6 MHz |
| FP64, DE1-SoC (Cyclone V) | 5,287 (16%) | 1,133 | 8 | ~40.6 MHz |
| FP32, TSMC 65nm | TBD | TBD | — | TBD |
| FP64, TSMC 65nm | TBD | TBD | — | TBD |

## Usage and Integration

Instantiate `fp_top` with the desired precision. Import `fp_pkg` for operation and rounding mode enumerations.

```systemverilog
import fp_pkg::*;

fp_top #(
    .FP_FORMAT  (FP32),   // FP32 or FP64
    .INT_FORMAT (INT32)   // INT32 or INT64
) fpu (
    .clk_i       (clk),
    .rst_i       (rst_n),   // active-low reset

    .start_i     (start),
    .ready_o     (ready),   // deasserted while a long operation (div/sqrt) is in progress

    .a_i         (a),       // 64-bit; lower FP_WIDTH bits are used
    .b_i         (b),
    .c_i         (c),       // FMA third operand

    .op_i        (FDIV),    // float_op_e from fp_pkg
    .op_modify_i (2'b00),   // operation sub-mode (e.g. sub vs add, sqrt vs div)
    .rnd_i       (RNE),     // roundmode_e from fp_pkg

    .result_o    (result),
    .valid_o     (valid),
    .flags_o     (flags)    // status_t: {NV, DZ, OF, UF, NX}
);
```

## Verification Status

Tested with Berkeley TestFloat (level 1, all 5 rounding modes: RNE RTZ RDN RUP RMM).

| Operation | FP32 | FP64 | Notes |
|-----------|------|------|-------|
| add | PASS | PASS | |
| sub | PASS | PASS | |
| mul | PASS | PASS | |
| div | PASS | PASS | |
| sqrt | PASS | PASS | |
| mulAdd (FMA) | PASS | PASS | f64_mulAdd fix in dev branch |
| le / eq / lt | PASS | PASS | |
| f2f conversion | PASS | PASS | f32↔f64 |
| int→float (i2f) | PASS | PASS | signed/unsigned × 32/64-bit |
| float→int (f2i) | PASS | PASS | signed/unsigned × 32/64-bit |
| min / max | PASS | PASS | Directed special-value tests (no testfloat_gen vectors) |
| classify | PASS | PASS | Directed special-value tests (no testfloat_gen vectors) |
| mulSub / negMulAdd / negMulSub | — | — | No testfloat_gen reference vectors |
| rem | — | — | Not implemented |

> **—** means the operation could not be verified automatically: either no Berkeley TestFloat reference vectors exist for it, or it is not yet implemented.

## Simulation (Verilator)

All simulation targets are available from the repo root.

### Single run

```bash
make sim TEST=f32_div ROUND_MODE=0 LEVEL=1
```

### All rounding modes for one operation

```bash
make sim-all TEST=f32_sqrt
```

### Full regression

```bash
make sim-regress          # level 1, ~2 min
make sim-regress LEVEL=2  # level 2, more thorough
```

Runs 176 Berkeley TestFloat tests (all ops × 5 rounding modes) plus directed
special-value tests for min/max/classify. Exit code is 0 on full pass, 1 on any
failure. Failures are logged to `simulation/regress_failures.txt`.

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TEST` | `f32_add` | Berkeley TestFloat operation keyword |
| `ROUND_MODE` | `1` | `0`=RNE `1`=RTZ `2`=RDN `3`=RUP `4`=RMM |
| `LEVEL` | `1` | TestFloat generation thoroughness (1 or 2) |
| `TRACE` | `0` | Set to `1` to enable waveform dump (writes `*.vcd`) |
| `VERILATOR_OPT` | `2` | Verilator optimisation level (0–3) |

> **Do not pass `RM=<value>`** on the command line. `RM` is a GNU Make built-in variable used for file removal; overriding it breaks the recursive Verilator build step. Use `ROUND_MODE` instead.

### Show all simulation options

```bash
make -C simulation help
```

## Formal Verification (SymbiYosys)

Properties are in `simulation/formal/fp_props.sv`. The flow uses `sv2v` to pre-process the RTL, then runs SymbiYosys in BMC mode (depth 32) with the Bitwuzla solver.

```bash
make formal   # requires sv2v and sby/bitwuzla
```

Properties verified (FP32 + FP64, RISC-V mode):

| ID | Property |
|----|----------|
| P1 | sNaN input always raises the Invalid (NV) flag |
| P2 | Any NaN result is canonical qNaN (`0x7FC00000`) |
| P3 | FSGNJ never raises any flags |
| P4 | FCLASS never raises any flags |
| P5 | Division by zero raises DZ, not NV |
| P6 | NaN-box violation produces canonical qNaN |
| P7 | ±Inf × ±0 raises NV |
| P8 | `valid_o` is a single-cycle pulse |
| P9 | `ready_o` deasserts the cycle after FDIV is accepted |

## Source file list

The file `simulation/src.args` lists all RTL source files compiled by both Verilator and QuestaSim. When adding a new module, append it there.

All modules in `src/` are included in `src.args` and are part of the verified design.

## Contribute

Contributions are welcome. Please open an issue or pull request on GitHub.
