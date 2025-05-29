// filepath: tb_fp32_div_comb.cpp
// Self-checking C++ testbench for the combinational IEEE-754 divider
#include <iostream>
#include <verilated.h>
#include "Vfp32_div_comb.h"
#include <cstdlib>
#include <ctime>
#include <cstdint>
#include <cmath>
#include <cfenv>
#include <iomanip>

int time_counter = 0;

int main(int argc, char** argv) {
    // seed random for varied FP32 inputs
    srand(static_cast<unsigned>(time(nullptr)));

    Verilated::commandArgs(argc, argv);

    Vfp32_div_comb* dut = new Vfp32_div_comb();

    while (time_counter < 50000000) {
        // generate random 32-bit pattern for input a (allow negative values)
        uint32_t rand_bits_a = ((uint32_t)(rand() & 0xFFFF) << 16) |
                              (uint32_t)(rand() & 0xFFFF);
         union { float f; uint32_t u; } conv_a;
         conv_a.u = rand_bits_a;

        // generate random 32-bit pattern for input b (allow negative values)
        uint32_t rand_bits_b = ((uint32_t)(rand() & 0xFFFF) << 16) |
                              (uint32_t)(rand() & 0xFFFF);
         union { float f; uint32_t u; } conv_b;
         conv_b.u = rand_bits_b;

        // drive inputs
        dut->a = conv_a.u;
        dut->b = conv_b.u;
        dut->eval();

        // capture RTL output
        union { uint32_t u; float f; } out_conv;
        out_conv.u = dut->y;

         // clear FP exceptions before libm division
         feclearexcept(FE_ALL_EXCEPT);
         union { uint32_t u; float f; } math_conv;
        math_conv.f = conv_a.f / conv_b.f;
        int math_flags = fegetexcept();

        int32_t rtl_bits  = static_cast<int32_t>(out_conv.u);
        int32_t math_bits = static_cast<int32_t>(math_conv.u);
        uint32_t ulp_diff = (rtl_bits > math_bits) ? (rtl_bits - math_bits) : (math_bits - rtl_bits);

        // treat NaN-to-NaN as passing
        bool is_nan_case = std::isnan(math_conv.f) && std::isnan(out_conv.f);
        bool pass = is_nan_case || (ulp_diff <= 1);

        // print detailed comparison, including exception flags
        std::cout << "Time: " << time_counter
                  << " | a: " << conv_a.f
                  << " (bits=0x" << std::hex << std::setw(8) << std::setfill('0') << conv_a.u << std::dec << ")"
                  << " | b: " << conv_b.f
                  << " (bits=0x" << std::hex << std::setw(8) << std::setfill('0') << conv_b.u << std::dec << ")"
                  << " | out(rtl): " << out_conv.f
                  << " (bits=0x" << std::hex << std::setw(8) << out_conv.u << std::dec << ")"
                  << " | out(math): " << math_conv.f
                  << " (bits=0x" << std::hex << std::setw(8) << math_conv.u << std::dec << ")"
                  << " | ulp_diff: " << ulp_diff
                  << (pass ? " PASS" : " FAIL")
                  // debug internals
                  << " | dbg_q_div=0x" << std::hex << std::setw(6) << std::setfill('0') << dut->dbg_q_div << std::dec
                  << " dbg_guard_div=" << static_cast<int>(dut->dbg_guard_div)
                  << " dbg_sticky_div=" << static_cast<int>(dut->dbg_sticky_div)
                  << " dbg_raw_div_full=0x" << std::hex << std::setw(14) << std::setfill('0') << static_cast<unsigned long long>(dut->dbg_raw_div_full) << std::dec
                  << " dbg_q25=0x" << std::hex << std::setw(7) << std::setfill('0') << dut->dbg_q25 << std::dec
                  << " dbg_m=0x"   << std::hex << std::setw(7) << std::setfill('0') << dut->dbg_m    << std::dec
                  << " dbg_lz_q="   << std::dec << static_cast<int>(dut->dbg_lz_q)
                  << " dbg_q_norm=0x" << std::hex << std::setw(13) << std::setfill('0') << static_cast<unsigned long long>(dut->dbg_q_norm) << std::dec
                  << " round_up=" << static_cast<int>(dut->round_up)
                  << " | math_flags=0x" << std::hex << math_flags << std::dec
                  << " | exc_invalid=" << static_cast<int>(dut->exc_invalid)
                  << " | exc_divzero=" << static_cast<int>(dut->exc_divzero)
                  << " | exc_overflow=" << static_cast<int>(dut->exc_overflow)
                  << " | exc_underflow=" << static_cast<int>(dut->exc_underflow)
                  << " | exc_inexact=" << static_cast<int>(dut->exc_inexact)
                  << std::endl;

        time_counter++;
    }

    dut->final();
    delete dut;
    return 0;
}
