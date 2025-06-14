#include "Vfp32_sqrt_comb.h"
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <iomanip> // for std::hex and std::setw
#include <iostream>
#include <verilated.h>
extern "C" {
#include "softfloat.h"
}

int time_counter = 0;

int main(int argc, char **argv) {
  // seed random for varied FP32 inputs
  srand(static_cast<unsigned>(time(nullptr)));

  Verilated::commandArgs(argc, argv);

  Vfp32_sqrt_comb *dut = new Vfp32_sqrt_comb();

  // === Corner-case tests for sqrt ===
  {
    union {
      float f;
      uint32_t u;
    } conv_cc, out_cc, math_cc;
    static const uint32_t corner_vals[] = {
        0x00000000, // +0
        0x80000000, // -0
        0x3f800000, // 1.0
        0x7f800000, // +inf
        0xff800000, // -inf
        0x7fc00000, // qNaN
        0x7fa00000, // sNaN
        0x00000001, // min subnormal
        0x00800000, // min normal
        0x7f7fffff, // max finite
        0x40e4006e, // 7.12505 (observed failure)
        0x016f609c, // 4.39667e-38 (observed failure)
        0x2812c1b1, // 8.14663e-15 (observed failure)
        0x67bee97d, // 1.80311e+24 (observed failure)
        0x1ab82050, // 7.61528e-23 (observed failure)
        0x59042172, // 2.32447e+15 (observed failure)
        0x321bbcdd, // 9.06513e-09 (observed failure)
        // Additional random failure cases
        0x36a9405f, // 5.04409e-06
        0x3fab6860, // 1.33912
        0x72cb1062, // 8.04419e+30
        0x6e002f83, // 9.91788e+27
        0x2605ba5a, // 4.63962e-16
        0x429850b4, // 76.1576
        0x696c0b48, // 1.7835e+25
        0x01cdf635, // 7.56584e-38
        0x4b975f95, // 1.98408e+07
        0x3b2c6f35, // 0.00263114
        0x3f800001, // just above 1.0 (round-nearest)
        0x4b000000, // 2^23 (exact int)
        0x00800001, // just above min normal
        0x00000002, // small subnormal
        0x3f000000, // 0.5 (exact)
        0x3e800000  // 0.25 (exact)
    };
    int num_cc = sizeof(corner_vals) / sizeof(corner_vals[0]);
    for (int i = 0; i < num_cc; ++i) {
      conv_cc.u = corner_vals[i];
      dut->a = conv_cc.u;
      dut->eval();
      out_cc.u = dut->y;
      // reference via SoftFloat
      softfloat_exceptionFlags = 0;
      float32_t a_sf_cc;
      a_sf_cc.v = conv_cc.u;
      float32_t r_sf_cc = f32_sqrt(a_sf_cc);
      int math_flags_cc = softfloat_exceptionFlags;
      math_cc.u = r_sf_cc.v;
      // ULP diff
      int32_t rtl_bits_cc = static_cast<int32_t>(out_cc.u);
      int32_t math_bits_cc = static_cast<int32_t>(math_cc.u);
      uint32_t ulp_diff_cc = (rtl_bits_cc > math_bits_cc)
                                 ? (rtl_bits_cc - math_bits_cc)
                                 : (math_bits_cc - rtl_bits_cc);
      // flags
      int dut_flags_cc = (dut->exc_invalid << 4) | (dut->exc_divzero << 3) |
                         (dut->exc_overflow << 2) | (dut->exc_underflow << 1) |
                         (dut->exc_inexact);
      bool is_nan_case_cc = std::isnan(math_cc.f) && std::isnan(out_cc.f);
      bool pass_cc = is_nan_case_cc || (ulp_diff_cc <= 1);
      std::cout << "[SQRT CASE " << i << "] a=" << conv_cc.f
                << " | rtl=" << out_cc.f << " math=" << math_cc.f
                << " | ulp_diff=" << ulp_diff_cc
                << (pass_cc ? " PASS" : " FAIL") << " | flags math=0x"
                << std::hex << math_flags_cc << " rtl=0x" << dut_flags_cc
                << std::dec << std::endl;
    }
    std::cout << "=== Sqrt corner-case tests done ===" << std::endl;
  }

  while (time_counter < 60000000) {
    // generate random 31-bit pattern for positive float
    uint32_t rand_bits =
        ((uint32_t)(rand() & 0x7FFF) << 16) | (uint32_t)(rand() & 0xFFFF);
    rand_bits &= 0x7FFFFFFF; // clear sign bit
    union {
      float f;
      uint32_t u;
    } conv;
    conv.u = rand_bits;
    float rand_val = conv.f;
    dut->a = conv.u;
    dut->eval(); // Evaluate the design

    // Convert the output back to float
    union {
      uint32_t u;
      float f;
    } out_conv;
    out_conv.u = dut->y;

    // clear FP exceptions and reference sqrt via SoftFloat
    softfloat_exceptionFlags = 0;
    float32_t a_sf;
    a_sf.v = conv.u;
    float32_t r_sf = f32_sqrt(a_sf);
    int math_flags = softfloat_exceptionFlags;
    union {
      uint32_t u;
      float f;
    } math_conv;
    math_conv.u = r_sf.v;

    int32_t rtl_bits = static_cast<int32_t>(out_conv.u);
    int32_t math_bits = static_cast<int32_t>(math_conv.u);
    uint32_t ulp_diff = (rtl_bits > math_bits) ? (rtl_bits - math_bits)
                                               : (math_bits - rtl_bits);
    // collect RTL exception flags and compare
    int dut_flags = (dut->exc_invalid << 4) | (dut->exc_divzero << 3) |
                    (dut->exc_overflow << 2) | (dut->exc_underflow << 1) |
                    (dut->exc_inexact);
    bool flag_pass = (dut_flags == math_flags);

    // If both outputs are NaN, consider as PASS
    bool is_nan_case = std::isnan(math_conv.f) && std::isnan(out_conv.f);
    // strict ULP match: only zero-difference or NaN-to-NaN passes
    bool pass = is_nan_case || (ulp_diff == 0);

    // Print the output values
    std::cout << "Time: " << time_counter << " | sqrt_in: " << conv.f
              << " (bits=0x" << std::hex << std::setw(8) << std::setfill('0')
              << conv.u << std::dec << ")" << " | sqrt_out(rtl): " << out_conv.f
              << " (bits=0x" << std::hex << std::setw(8) << std::setfill('0')
              << out_conv.u << std::dec << ")"
              << " | sqrt_out(math): " << math_conv.f << " (bits=0x" << std::hex
              << std::setw(8) << std::setfill('0') << math_conv.u << std::dec
              << ")" << " | ulp_diff: " << ulp_diff
              << (pass ? " PASS" : " FAIL")
              << " | FLAG=" << (flag_pass ? " PASS" : " FAIL")
              << " | math_flags=0x" << std::hex << math_flags << std::dec
              << " | dut_flags=0x" << std::hex << dut_flags << std::dec
              << std::endl;

    time_counter++;
  }

  dut->final();
  delete dut; // Clean up the allocated memory
  return 0;
}