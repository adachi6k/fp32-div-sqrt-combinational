verilator --exe --top-module fp32_div_comb --build --cc fp32_div_comb.sv -exe tb_fp32_div_comb.cpp
verilator --exe --top-module fp32_sqrt_comb --build --cc fp32_sqrt_comb.sv -exe tb_fp32_sqrt_comb.cpp
