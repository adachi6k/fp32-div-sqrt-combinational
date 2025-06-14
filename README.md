
build command

```shell
cd softfloat/build/Linux-x86_64-GCC
make
```

```shell
verilator --exe --top-module fp32_div_comb --build --cc fp32_div_comb.sv -exe tb_fp32_div_comb.cpp  -CFLAGS "-I$(pwd)/softfloat/source/include" -LDFLAGS "-L$(pwd)/softfloat/build/Linux-x86_64-GCC -l:softfloat.a"
verilator --exe --top-module fp32_sqrt_comb --build --cc fp32_sqrt_comb.sv -exe tb_fp32_sqrt_comb.cpp  -CFLAGS "-I$(pwd)/softfloat/source/include" -LDFLAGS "-L$(pwd)/softfloat/build/Linux-x86_64-GCC -l:softfloat.a"
```
