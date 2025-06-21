# Simple Makefile for fp32 div and sqrt with SoftFloat
# Based on README.md instructions

VERILATOR = verilator
CC        = gcc
CXX       = g++

# Paths to SoftFloat
ROOTDIR := $(shell pwd)
SOFT_INCLUDE_DIR := $(ROOTDIR)/softfloat/source/include
SOFT_BUILD_DIR   := $(ROOTDIR)/softfloat/build/Linux-x86_64-GCC
SOFT_LIB         := $(SOFT_BUILD_DIR)/softfloat.a

# Compiler flags: include SoftFloat headers and build directory (for platform.h)
CFLAGS    = -I$(SOFT_INCLUDE_DIR) -I$(SOFT_BUILD_DIR)
LDFLAGS   = -L$(SOFT_BUILD_DIR) -l:softfloat.a

# Targets
.PHONY: all div sqrt debug_div clean
all: div sqrt

# Build and run fp32_div_comb testbench
div:
	$(VERILATOR) --threads 4 --top-module fp32_div_comb --build --cc fp32_div_comb.sv fp32_sqrt_comb.sv \
		--exe tb_fp32_div_comb.cpp -CFLAGS "$(CFLAGS)" -LDFLAGS "$(LDFLAGS)"

# Build and run fp32_sqrt_comb testbench
sqrt:
	$(VERILATOR) --threads 4 --top-module fp32_sqrt_comb --build --cc fp32_sqrt_comb.sv \
		--exe tb_fp32_sqrt_comb.cpp -CFLAGS "$(CFLAGS)" -LDFLAGS "$(LDFLAGS)"

# Build debug version for specific cases
debug_div:
	$(VERILATOR) --threads 4 --top-module fp32_div_comb --build --cc fp32_div_comb.sv \
		--exe debug_div.cpp -CFLAGS "$(CFLAGS)" -LDFLAGS "$(LDFLAGS)"

# Clean artifacts
clean:
	rm -rf obj_dir
	rm -f Vfp32_div_comb Vfp32_sqrt_comb
