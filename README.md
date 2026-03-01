# IEEE-754 FP32 Combinational Arithmetic Units

[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-green.svg)]()
[![Tested](https://img.shields.io/badge/Testing-SoftFloat_Verified-brightgreen.svg)]()

A professional-grade, synthesizable implementation of IEEE-754 single-precision (FP32) combinational divider and square-root units in SystemVerilog.

## 🎯 Overview

This project provides high-performance, combinational floating-point arithmetic units designed for production FPGA/ASIC implementation:

- **`fp32_div_comb.sv`**: Combinational FP32 divider with full IEEE-754 compliance
- **`fp32_sqrt_comb.sv`**: Combinational FP32 square-root with IEEE-754 compliance  
- **Comprehensive Verification**: Self-checking testbenches using Verilator and SoftFloat reference
  - `tb_fp32_div_comb.cpp`: 60M+ test vectors including systematic and stratified random testing
  - `tb_fp32_sqrt_comb.cpp`: Extensive corner-case and random testing for square-root

## ✨ Key Features

- **🚀 Pure Combinational Logic**: No clocks, resets, or flip-flops - ideal for high-throughput pipelined designs
- **📐 IEEE-754 Compliant**: Full support for special values, all exception flags, and round-to-nearest-even
- **🎯 Bit-Exact Accuracy**: Zero ULP errors - matches Berkeley SoftFloat reference implementation exactly
- **⚡ Synthesis Optimized**: Clean SystemVerilog designed for optimal FPGA/ASIC synthesis results
- **🧪 Production-Ready Testing**: 
  - Corner cases for all IEEE-754 special values
  - Systematic boundary testing for subnormal regions
  - Stratified random testing across entire FP32 space
  - Early-exit testing for efficient debugging
- **📋 Professional Quality**: MIT licensed, comprehensive documentation, unified coding standards

## Design Intent

- **High Performance**: Optimized for maximum combinational delay budget in pipelined processors
- **Correctness**: Bit-exact IEEE-754 compliance including proper flag generation
- **Maintainability**: Clear, well-documented SystemVerilog with algorithmic comments
- **Verification**: Exhaustive testing methodology ensuring confidence in correctness

## Prerequisites

- **Verilator** (v4.0+): For RTL simulation and testbench compilation
- **GNU Make**, **g++**, **gcc**: Standard build tools
- **SoftFloat library**: Berkeley reference implementation for verification
  - Built under `softfloat/build/Linux-x86_64-GCC/` with `softfloat.a` and headers
- **Optional**: Verible, svlint for additional code quality checks

## Build & Test

1. **Build SoftFloat reference library** (RISC-V specialization):
   ```bash
   make softfloat      # Builds with SPECIALIZE_TYPE=RISCV (default)
   ```

2. **Run comprehensive tests**:
   ```bash
   make all      # Build and test both divider and sqrt units
   make div      # Build and test divider only
   make sqrt     # Build and test sqrt only
   make clean    # Clean all generated files
   ```

3. **Test output interpretation**:
   - Corner cases are tested first with detailed pass/fail reporting
   - Random testing follows with millions of test vectors
   - ULP (Unit in Last Place) differences and IEEE-754 exception flags are verified
   - Tests pass when results match SoftFloat bit-exactly

## Module Interface

### FP32 Divider (`fp32_div_comb`)
```systemverilog
module fp32_div_comb (
    input  logic [31:0] a,              // Dividend (IEEE-754 FP32)
    input  logic [31:0] b,              // Divisor (IEEE-754 FP32)
    output logic        exc_invalid,    // Invalid operation flag
    output logic        exc_divzero,    // Divide by zero flag
    output logic        exc_overflow,   // Overflow flag
    output logic        exc_underflow,  // Underflow flag
    output logic        exc_inexact,    // Inexact result flag
    output logic [31:0] y               // Result a/b (IEEE-754 FP32)
);
```

### FP32 Square Root (`fp32_sqrt_comb`)
```systemverilog
module fp32_sqrt_comb (
    input  logic [31:0] a,              // Input (IEEE-754 FP32)
    output logic        exc_invalid,    // Invalid operation flag (sqrt of negative)
    output logic        exc_inexact,    // Inexact result flag
    output logic [31:0] y               // Result sqrt(a) (IEEE-754 FP32)
);
```

## Implementation Details

- **Algorithm**: Restoring division for divider, radix-4 pair-bit method for sqrt
- **Precision**: Full 24-bit mantissa precision with proper guard/round/sticky bits
- **Special Cases**: Complete handling of ±0, ±∞, NaN, subnormals per IEEE-754
- **Rounding**: Round-to-nearest-even (ties to even) as per IEEE-754 default
- **Exception Flags**: Full IEEE-754 exception flag generation

### IEEE-754 Implementation-Defined Behavior

IEEE-754 leaves certain behaviors as implementation-defined. This project follows
the **RISC-V** specification for these choices:

| Item | Behavior | IEEE-754 Reference |
|------|----------|--------------------|
| **Default NaN** | Canonical positive quiet NaN `0x7FC00000` | §6.2.3 — sign of default NaN is not specified |
| **NaN propagation** | Always returns canonical NaN; input payload is not preserved | §6.2.3 — propagation rules are implementation-defined |
| **NaN signaling** | Any signaling NaN input raises the invalid-operation exception | §7.2 |
| **Rounding mode** | Round-to-nearest-even (RNE) only | §4.3.1 |
| **Tininess detection** | Before rounding | §7.5 — may be detected before or after rounding |

The reference model used for verification is [Berkeley SoftFloat](http://www.jhauser.us/arithmetic/SoftFloat.html)
built with `SPECIALIZE_TYPE = RISCV` (see `softfloat/build/Linux-x86_64-GCC/Makefile`).
Changing the specialization (e.g., to `8086-SSE` or `ARM-VFPv2`) will change
default-NaN encoding and propagation rules, causing test mismatches.

## Verification Strategy

The testbenches employ a multi-layered verification approach:

1. **Corner Case Testing**: Systematic testing of boundary conditions
   - All special value combinations (±0, ±∞, NaN)
   - Subnormal boundaries and gradual underflow
   - Overflow boundaries
   - Perfect squares and exact results
   - Rounding tie cases

2. **Random Testing**: Millions of pseudo-random input combinations
   - Uniform distribution across all possible FP32 values
   - Statistical coverage of rare cases
   - Long-running stress testing

3. **Reference Comparison**: Bit-exact comparison with Berkeley SoftFloat
   - Result values must match exactly (0 ULP difference)
   - Exception flags must match exactly
   - Comprehensive flag verification for all IEEE-754 conditions

## License

This project is released under the **MIT License**. See the `LICENSE` file for details.

## Revision History

| Date       | Description |
|------------|-------------|
| 2026-03-01 | Adopt RISC-V NaN specification: canonical NaN (`0x7FC00000`), no payload propagation. Switch SoftFloat to `SPECIALIZE_TYPE = RISCV`. Document implementation-defined behavior in README. |
| 2026-03-01 | Fix testbench silent-pass bugs: add failure exits, strict NaN comparison, result value checks, and boundary test activation |
| 2026-03-01 | Refactor `exp_sum` carry handling in divider; fix off-by-one in random range generation; correct misleading comments |
| 2026-03-01 | Fix `count_lz` default return value from 0 to 24 for all-zero 24-bit input in `fp32_div_comb.sv` |
