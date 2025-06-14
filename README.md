# fp32-sqrt-comb

A simple, synthesizable, pure-combinational implementation of IEEE-754 single-precision (FP32) divider and square-root units.

This project provides:

- `fp32_div_comb.sv`: Combinational FP32 divider (no reset or flip-flops)
- `fp32_sqrt_comb.sv`: Combinational FP32 square-root (no reset or flip-flops)
- Self-checking C++ testbenches using Verilator and the SoftFloat reference library:
  - `tb_fp32_div_comb.cpp`
  - `tb_fp32_sqrt_comb.cpp`

## Design Intent

- **Simplicity**: Clear Verilog/SystemVerilog code for divider and sqrt, focusing on basic IEEE-754 behavior.
- **Synthesizability**: Pure combinational logic (no registers), suitable for high-throughput pipelines with external pipeline registers if needed.
- **Self-Verification**: Testbenches compare RTL outputs and exception flags against SoftFloat reference for corner cases and random inputs.

## Prerequisites

- **Verilator**
- **GNU Make**, **g++**, **gcc**
- SoftFloat library built under `softfloat/build/Linux-x86_64-GCC/` (provide `softfloat.a` and headers)

## Build & Test

1. Build SoftFloat (if not already built):
   ```sh
   cd softfloat/build/Linux-x86_64-GCC
   make
   cd ../../
   ```

2. From project root, run:
   ```sh
   make all      # builds both divider and sqrt testbenches
   make div      # builds and tests divider
   make sqrt     # builds and tests square-root
   make clean    # clean all generated files
   ```

Each test prints corner-case results followed by random-input passes/fails, including ULP differences and IEEE-754 exception flags.

## License

This project is released under the **MIT License**. See the `LICENSE` file for details.

build command

```shell
cd softfloat/build/Linux-x86_64-GCC
make
```

```shell
verilator --exe --top-module fp32_div_comb --build --cc fp32_div_comb.sv -exe tb_fp32_div_comb.cpp  -CFLAGS "-I$(pwd)/softfloat/source/include" -LDFLAGS "-L$(pwd)/softfloat/build/Linux-x86_64-GCC -l:softfloat.a"
verilator --exe --top-module fp32_sqrt_comb --build --cc fp32_sqrt_comb.sv -exe tb_fp32_sqrt_comb.cpp  -CFLAGS "-I$(pwd)/softfloat/source/include" -LDFLAGS "-L$(pwd)/softfloat/build/Linux-x86_64-GCC -l:softfloat.a"
```
