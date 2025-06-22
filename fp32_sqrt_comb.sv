/*
 * MIT License
 * 
 * Copyright (c) 2025 adachi6k
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 */

/**
 * @file    fp32_sqrt_comb.sv
 * @brief   Combinational IEEE-754 Single-Precision Floating-Point Square Root
 * @author  adachi6k
 * @date    2025
 * 
 * @description
 * This module implements a fully combinational IEEE-754 single-precision 
 * floating-point square root unit. It supports IEEE-754 exception handling
 * and produces accurate results for positive inputs.
 * 
 * Features:
 * - IEEE-754 compliance for square root operation
 * - Exception flags (invalid, overflow, underflow, inexact)
 * - Round-to-nearest-even (default) rounding mode
 * - Optimized for synthesis and timing closure
 * 
 * @note Resource usage: Non-restoring square root algorithm implementation
 */

// Combinational IEEE-754 Single-Precision Floating-Point Square Root
module fp32_sqrt_comb (
    // Input operand
    input  logic [31:0] a,                 // input (IEEE-754 FP32)
    
    // IEEE-754 exception flags output
    output logic        exc_invalid,       // invalid operation (sqrt of negative)
    output logic        exc_divzero,       // divide-by-zero (unused for sqrt)
    output logic        exc_overflow,      // result magnitude too large (unused for sqrt)
    output logic        exc_underflow,     // result magnitude too small (gradual underflow)
    output logic        exc_inexact,       // result is not exactly representable
    
    // Result output
    output logic [31:0] y                  // square root (IEEE-754 FP32)
);

  // Unpack input
  logic        sign;
  logic [ 7:0] exp;
  logic [22:0] frac;
  logic [ 7:0] out_exp;
  logic [23:0] sqrt_frac;
  logic [31:0] result;

  // Special cases
  logic is_zero, is_inf, is_nan, is_neg;

  assign sign = a[31];
  assign exp = a[30:23];
  assign frac = a[22:0];

  assign is_zero = (exp == 8'd0) && (frac == 23'd0);
  assign is_inf = (exp == 8'hff) && (frac == 23'd0);
  assign is_nan = (exp == 8'hff) && (frac != 23'd0);
  assign is_neg = sign && !is_zero;

  // Function to count leading zeros in 24-bit mantissa
  function automatic [4:0] count_lz(input logic [23:0] mant);
    reg [4:0] idx;
    begin
      count_lz = 5'd0;
      for (idx = 5'd23; idx != 5'd31; idx = idx - 1) begin
        if (mant[idx]) begin
          count_lz = 5'd23 - idx;
          break;
        end
      end
    end
  endfunction

  // Normalize subnormal numbers: only mantissa LZD
  logic [23:0] norm_mant;
  always_comb begin
    if (exp == 8'd0 && frac != 23'd0) begin
      // Subnormal: shift mantissa to normalize
      norm_mant = ({1'b0, frac} << count_lz({1'b0, frac}));
    end else begin
      // Normalized or zero
      norm_mant = {1'b1, frac};
    end
  end

  // Calculate sqrt exponent: signed unbiased then half and rebias
  logic signed [9:0] exp_unbias_s;
  logic        [7:0] sqrt_exp;
  logic signed [9:0] rebias;
  // Prevent unused bit warnings
  logic              unused_sqrt_frac_msb;
  logic        [1:0] unused_rebias_hi;

  always_comb begin
    // compute signed unbiased exponent
    if (exp == 8'd0 && frac != 23'd0) begin
      exp_unbias_s = -10'sd126 - $signed({5'd0, count_lz({1'b0, frac})});
    end else if (exp == 8'd0) begin
      exp_unbias_s = -10'sd127;
    end else begin
      exp_unbias_s = $signed({2'b00, exp}) - 10'sd127;
    end
    // divide by 2 and rebias
    rebias   = (exp_unbias_s >>> 1) + 10'sd127;
    sqrt_exp = rebias[7:0];
  end

  // Calculate sqrt mantissa using radix-4 (pair-bit) algorithm (25bit result + guard)
  logic [24:0] sqrt_op;
  // extended operand (2*25 bits)
  logic [49:0] op50;
  // raw result plus sticky bit for correct rounding
  logic [25:0] raw_sticky;
  logic [24:0] raw_root;
  logic guard_bit, sticky_bit;
  logic [23:0] root_rounded;
  // intermediate extended rounded result
  logic [24:0] rounded_ext;

  // radix-4 pair-bit square root function returning {sticky, root[24:0]}
  // input: 50-bit operand; output[25] = sticky, [24:0] result bits (LSB is guard)
  function automatic [25:0] sqrt_pair(input logic [49:0] op50_arg);
    integer i;
    reg [49:0] rem;
    reg [24:0] root;
    reg [1:0] next2;
    begin
      rem  = 0;
      root = 0;
      for (i = 24; i >= 0; i = i - 1) begin
        next2 = op50_arg[2*i+:2];
        // shift remainder by 2 bits and append next2
        rem   = {rem[47:0], next2};
        // trial divisor as 50-bit: zero-extend {root,2'b01}
        if (rem >= {23'b0, root, 2'b01}) begin
          rem  = rem - {23'b0, root, 2'b01};
          // append '1' bit to root
          root = {root[23:0], 1'b1};
        end else begin
          // append '0' bit to root
          root = {root[23:0], 1'b0};
        end
      end
      sqrt_pair = {|rem, root};
    end
  endfunction

  always_comb begin
    // defaults to avoid latches
    exc_invalid          = 1'b0;
    exc_divzero          = 1'b0;
    exc_overflow         = 1'b0;
    exc_underflow        = 1'b0;
    exc_inexact          = 1'b0;
    // default signals (avoid latches)
    result               = '0;
    unused_sqrt_frac_msb = 1'b0;
    unused_rebias_hi     = 2'b0;
    sqrt_op              = '0;
    op50                 = '0;
    raw_sticky           = '0;
    raw_root             = '0;
    guard_bit            = '0;
    sticky_bit           = '0;
    root_rounded         = '0;
    sqrt_frac            = '0;
    out_exp              = '0;
    rounded_ext          = '0;
    if (is_nan) begin
      // NaN input: only signaling NaN raises invalid
      exc_invalid = (frac[22] == 1'b0) ? 1'b1 : 1'b0;
      result = 32'h7fc00000;
    end else if (is_neg && !is_zero) begin
      // negative input (except -0): invalid operation
      exc_invalid = 1'b1;
      result = 32'h7fc00000;
    end else if (is_inf) begin
      // Infinity
      result = 32'h7f800000;
    end else if (is_zero) begin
      // Zero
      result = a;
    end else begin
      // Normal case
      // Guard-bit rounding path: select even/odd exponent shift
      // select even/odd exponent shift based on signed unbiased exponent
      sqrt_op     = exp_unbias_s[0] ? {norm_mant, 1'b0} : {1'b0, norm_mant};
      // build 50-bit operand: sqrt_op << 25
      op50        = {sqrt_op, 25'b0};
      // compute pair-bit sqrt
      raw_sticky  = sqrt_pair(op50);
      raw_root    = raw_sticky[24:0];
      guard_bit   = raw_root[0];
      sticky_bit  = raw_sticky[25];
      // inexact if any rounding bits set
      exc_inexact = guard_bit | sticky_bit;
      // round-to-nearest-even with overflow detection
      rounded_ext = {1'b0, raw_root[24:1]} + {24'b0, guard_bit & (raw_root[1] | sticky_bit)};
      if (rounded_ext[24]) begin
        // rounding overflow, adjust mantissa and exponent
        root_rounded = rounded_ext[24:1];
        out_exp      = sqrt_exp[7:0] + 1;
      end else begin
        root_rounded = rounded_ext[23:0];
        out_exp      = sqrt_exp[7:0];
      end
      sqrt_frac = root_rounded;
      // dummy assignments for lint
      unused_sqrt_frac_msb = sqrt_frac[23];
      unused_rebias_hi    = rebias[9:8];
      // produce final result
      result = {1'b0, out_exp, sqrt_frac[22:0]};
    end
  end

  assign y = result;

endmodule
