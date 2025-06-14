#include <iostream>
#include <verilated.h>
#include "Vfp32_sqrt_comb.h"
#include <cstdlib>
#include <ctime>
#include <cstdint>
#include <cmath>
#include <iomanip>  // for std::hex and std::setw
extern "C" {
#include "softfloat.h"
}

int time_counter = 0;

int main(int argc, char** argv) {
    // seed random for varied FP32 inputs
    srand(static_cast<unsigned>(time(nullptr)));

    Verilated::commandArgs(argc, argv);

    Vfp32_sqrt_comb* dut = new Vfp32_sqrt_comb();

    while (time_counter < 60000000) {
         // generate random 31-bit pattern for positive float
         uint32_t rand_bits = ((uint32_t)(rand() & 0x7FFF) << 16) |
                              (uint32_t)(rand() & 0xFFFF);
         rand_bits &= 0x7FFFFFFF; // clear sign bit
         union { float f; uint32_t u; } conv;
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
         float32_t a_sf; a_sf.v = conv.u;
         float32_t r_sf = f32_sqrt(a_sf);
         int math_flags = softfloat_exceptionFlags;
         union { uint32_t u; float f; } math_conv;
         math_conv.u = r_sf.v;

         int32_t rtl_bits = static_cast<int32_t>(out_conv.u);
         int32_t math_bits = static_cast<int32_t>(math_conv.u);
         uint32_t ulp_diff = (rtl_bits > math_bits) ? (rtl_bits - math_bits) : (math_bits - rtl_bits);
         // collect RTL exception flags and compare
         int dut_flags =
            (dut->exc_invalid << 4) |
            (dut->exc_divzero << 3) |
            (dut->exc_overflow << 2) |
            (dut->exc_underflow << 1) |
            (dut->exc_inexact);
        bool flag_pass = (dut_flags == math_flags);

         // If both outputs are NaN, consider as PASS
         bool is_nan_case = std::isnan(math_conv.f) && std::isnan(out_conv.f);
         bool pass = is_nan_case || (ulp_diff <= 1);

         // Print the output values
         std::cout << "Time: " << time_counter
                   << " | sqrt_in: " << conv.f
                   << " (bits=0x" << std::hex << std::setw(8) << std::setfill('0') << conv.u << std::dec << ")"
                   << " | sqrt_out(rtl): " << out_conv.f
                   << " (bits=0x" << std::hex << std::setw(8) << std::setfill('0') << out_conv.u << std::dec << ")"
                   << " | sqrt_out(math): " << math_conv.f
                   << " (bits=0x" << std::hex << std::setw(8) << std::setfill('0') << math_conv.u << std::dec << ")"
                   << " | ulp_diff: " << ulp_diff
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