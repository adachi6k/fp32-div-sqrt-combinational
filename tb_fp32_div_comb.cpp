// filepath: tb_fp32_div_comb.cpp
// Self-checking C++ testbench for the combinational IEEE-754 divider
#include "Vfp32_div_comb.h"
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <verilated.h>
// SoftFloat reference library
extern "C" {
#include "softfloat.h"
}

int time_counter = 0;

int main(int argc, char **argv) {
  // seed random for varied FP32 inputs
  srand(static_cast<unsigned>(time(nullptr)));

  Verilated::commandArgs(argc, argv);

  Vfp32_div_comb *dut = new Vfp32_div_comb();

  // === Corner-case tests ===
  {
    union {
      float f;
      uint32_t u;
    } conv_a_cc, conv_b_cc;
    static const struct {
      uint32_t a, b;
    } corner_cases[] = {
        {0x00000000, 0x00000000}, // 0/0
        {0x00000000, 0x3f800000}, // 0/1
        {0x80000000, 0x3f800000}, // -0/1
        {0x3f800000, 0x00000000}, // 1/0
        {0x7f800000, 0x3f800000}, // inf/1
        {0x7f800000, 0x7f800000}, // inf/inf
        {0x3f800000, 0x7f800000}, // 1/inf
        {0x7fc00000, 0x3f800000}, // qNaN/1
        {0x7fa00000, 0x3f800000}, // sNaN/1
        {0x00000001, 0x00000001}, // min subnormal/min subnormal
        {0x00800000, 0x00800000}, // min normal/min normal
        {0x7f7fffff, 0x3f800000}, // max finite/1
        {0x3781fd3f, 0xf8480000}  // 1.54959e-05 / -1.62259e+34 (observed underflow/inexact mismatch)
    };
    int num_cc = sizeof(corner_cases) / sizeof(corner_cases[0]);
    for (int i = 0; i < num_cc; ++i) {
      conv_a_cc.u = corner_cases[i].a;
      conv_b_cc.u = corner_cases[i].b;
      dut->a = conv_a_cc.u;
      dut->b = conv_b_cc.u;
      dut->eval();
      // capture outputs
      union {
        uint32_t u;
        float f;
      } out_cc;
      out_cc.u = dut->y;
      // collect RTL flags
      int dut_flags_cc = (dut->exc_invalid << 4) | (dut->exc_divzero << 3) |
                         (dut->exc_overflow << 2) | (dut->exc_underflow << 1) |
                         (dut->exc_inexact);
      // reference via SoftFloat
      softfloat_exceptionFlags = 0;
      float32_t a_sf_cc;
      a_sf_cc.v = conv_a_cc.u;
      float32_t b_sf_cc;
      b_sf_cc.v = conv_b_cc.u;
      float32_t r_sf_cc = f32_div(a_sf_cc, b_sf_cc);
      int math_flags_cc = softfloat_exceptionFlags;
      union {
        uint32_t u;
        float f;
      } math_cc;
      math_cc.u = r_sf_cc.v;
      // ULP diff
      int32_t rtl_bits_cc = static_cast<int32_t>(out_cc.u);
      int32_t math_bits_cc = static_cast<int32_t>(math_cc.u);
      uint32_t ulp_diff_cc = (rtl_bits_cc > math_bits_cc)
                                 ? (rtl_bits_cc - math_bits_cc)
                                 : (math_bits_cc - rtl_bits_cc);
      bool is_nan_case_cc = std::isnan(math_cc.f) && std::isnan(out_cc.f);
      bool pass_cc = is_nan_case_cc || (ulp_diff_cc <= 1);
      // print
      std::cout << "[CASE " << i << "] a=" << conv_a_cc.f
                << " b=" << conv_b_cc.f << " | rtl=" << out_cc.f
                << " math=" << math_cc.f << " | ulp_diff=" << ulp_diff_cc
                << (pass_cc ? " PASS" : " FAIL") << " | flags math=0x"
                << std::hex << math_flags_cc << " rtl=0x" << dut_flags_cc
                << std::dec << std::endl;
    }
    std::cout << "=== Corner-case tests done ===" << std::endl;
  }

  while (time_counter < 60000000) {
    // generate random 32-bit pattern for input a (allow negative values)
    uint32_t rand_bits_a =
        ((uint32_t)(rand() & 0xFFFF) << 16) | (uint32_t)(rand() & 0xFFFF);
    union {
      float f;
      uint32_t u;
    } conv_a;
    conv_a.u = rand_bits_a;

    // generate random 32-bit pattern for input b (allow negative values)
    uint32_t rand_bits_b =
        ((uint32_t)(rand() & 0xFFFF) << 16) | (uint32_t)(rand() & 0xFFFF);
    union {
      float f;
      uint32_t u;
    } conv_b;
    conv_b.u = rand_bits_b;

    // drive inputs
    dut->a = conv_a.u;
    dut->b = conv_b.u;
    dut->eval();

    // capture RTL output
    union {
      uint32_t u;
      float f;
    } out_conv;
    out_conv.u = dut->y;
    int dut_flags = (dut->exc_invalid << 4) | (dut->exc_divzero << 3) |
                    (dut->exc_overflow << 2) | (dut->exc_underflow << 1) |
                    (dut->exc_inexact);

    // clear FP exceptions before libm division
    // SoftFloat reference division
    softfloat_exceptionFlags = 0;
    // float32_t a_sf = ui32_to_f32(conv_a.u);
    // float32_t b_sf = ui32_to_f32(conv_b.u);
    float32_t a_sf;
    float32_t b_sf;
    a_sf.v = conv_a.u;
    b_sf.v = conv_b.u;
    float32_t r_sf = f32_div(a_sf, b_sf);
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

    // treat NaN-to-NaN as passing
    bool is_nan_case = std::isnan(math_conv.f) && std::isnan(out_conv.f);
    bool pass = is_nan_case || (ulp_diff <= 1);
    bool flag_pass = (dut_flags == math_flags);

    // print detailed comparison, including exception flags
    std::cout << "Time: " << time_counter << " | a: " << conv_a.f << " (bits=0x"
              << std::hex << std::setw(8) << std::setfill('0') << conv_a.u
              << std::dec << ")" << " | b: " << conv_b.f << " (bits=0x"
              << std::hex << std::setw(8) << std::setfill('0') << conv_b.u
              << std::dec << ")" << " | out(rtl): " << out_conv.f << " (bits=0x"
              << std::hex << std::setw(8) << out_conv.u << std::dec << ")"
              << " | out(math): " << math_conv.f << " (bits=0x" << std::hex
              << std::setw(8) << math_conv.u << std::dec << ")"
              << " | ulp_diff: " << ulp_diff
              << (pass ? " PASS" : " FAIL")
              // debug internals
              << " | dbg_q_div=0x" << std::hex << std::setw(6)
              << std::setfill('0') << dut->dbg_q_div << std::dec
              << " dbg_guard_div=" << static_cast<int>(dut->dbg_guard_div)
              << " dbg_sticky_div=" << static_cast<int>(dut->dbg_sticky_div)
              << " dbg_raw_div_full=0x" << std::hex << std::setw(14)
              << std::setfill('0')
              << static_cast<unsigned long long>(dut->dbg_raw_div_full)
              << std::dec << " dbg_q25=0x" << std::hex << std::setw(7)
              << std::setfill('0') << dut->dbg_q25 << std::dec << " dbg_m=0x"
              << std::hex << std::setw(7) << std::setfill('0') << dut->dbg_m
              << std::dec << " dbg_lz_q=" << std::dec
              << static_cast<int>(dut->dbg_lz_q) << " dbg_q_norm=0x" << std::hex
              << std::setw(13) << std::setfill('0')
              << static_cast<unsigned long long>(dut->dbg_q_norm) << std::dec
              << " round_up=" << static_cast<int>(dut->round_up)
              << " |FLAG=" << (flag_pass ? " PASS" : " FAIL")
              << " | math_flags=0x" << std::hex << math_flags << std::dec
              << " | dut_flags=0x" << std::hex << dut_flags << std::dec;

    std::cout << std::endl;

    time_counter++;
  }

  dut->final();
  delete dut;
  return 0;
}
