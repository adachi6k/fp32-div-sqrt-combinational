# fp32-div-sqrt-combinational

A synthesizable, pure-combinational implementation of IEEE-754 single-precision (FP32) divider and square-root units in SystemVerilog.

This project provides high-performance, combinational floating-point arithmetic units suitable for FPGA/ASIC implementation:

- `fp32_div_comb.sv`: Combinational FP32 divider with full IEEE-754 compliance
- `fp32_sqrt_comb.sv`: Combinational FP32 square-root with full IEEE-754 compliance
- Comprehensive self-checking testbenches using Verilator and SoftFloat reference:
  - `tb_fp32_div_comb.cpp`: Extensive corner-case and random testing for divider
  - `tb_fp32_sqrt_comb.cpp`: Extensive corner-case and random testing for square-root

## Key Features

- **Pure Combinational Logic**: No clocks, resets, or flip-flops - suitable for high-throughput pipelined designs
- **IEEE-754 Compliant**: Full support for special values, exception flags, and rounding modes
- **SoftFloat Verified**: Bit-exact matching with Berkeley SoftFloat reference implementation
- **Synthesis Ready**: Clean SystemVerilog code optimized for FPGA/ASIC synthesis
- **Comprehensive Testing**: Thousands of corner cases plus millions of random test vectors
- **Lint Clean**: Passes Verilator and Verible linting with zero warnings

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

1. **Build SoftFloat reference library** (if not already built):
   ```bash
   cd softfloat/build/Linux-x86_64-GCC
   make
   cd ../../../
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

- **Algorithm**: Restoring division for divider, Newton-Raphson iteration for sqrt
- **Precision**: Full 24-bit mantissa precision with proper guard/round/sticky bits
- **Special Cases**: Complete handling of ±0, ±∞, NaN, subnormals per IEEE-754
- **Rounding**: Round-to-nearest-even (ties to even) as per IEEE-754 default
- **Exception Flags**: Full IEEE-754 exception flag generation

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
cd softfloat/build/Linux-x86_64-GCC
make
```

```shell
verilator --exe --top-module fp32_div_comb --build --cc fp32_div_comb.sv -exe tb_fp32_div_comb.cpp  -CFLAGS "-I$(pwd)/softfloat/source/include" -LDFLAGS "-L$(pwd)/softfloat/build/Linux-x86_64-GCC -l:softfloat.a"
verilator --exe --top-module fp32_sqrt_comb --build --cc fp32_sqrt_comb.sv -exe tb_fp32_sqrt_comb.cpp  -CFLAGS "-I$(pwd)/softfloat/source/include" -LDFLAGS "-L$(pwd)/softfloat/build/Linux-x86_64-GCC -l:softfloat.a"
```
