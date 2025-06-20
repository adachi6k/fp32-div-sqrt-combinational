// filepath: fp32_div_comb.sv
// Combinational IEEE754 single-precision divider
module fp32_div_comb (
    input  logic [31:0] a,                 // dividend
    input  logic [31:0] b,                 // divisor
    output logic        exc_invalid,       // IEEE-754 exception: invalid operation
    output logic        exc_divzero,       // IEEE-754 exception: divide-by-zero
    output logic        exc_overflow,      // IEEE-754 exception: overflow
    output logic        exc_underflow,     // IEEE-754 exception: underflow
    output logic        exc_inexact,       // IEEE-754 exception: inexact result
    output logic [31:0] y                  // result
);

  // debug signals
  logic [50:0] dbg_raw_div_full   /*verilator public_flat*/;
  logic [24:0] dbg_q25            /*verilator public_flat*/;
  logic [ 5:0] dbg_lz_q           /*verilator public_flat*/;
  logic [49:0] dbg_q_norm         /*verilator public_flat*/;
  logic [23:0] dbg_q_div          /*verilator public_flat*/;
  logic [24:0] dbg_m              /*verilator public_flat*/;
  logic        dbg_guard_div      /*verilator public_flat*/;
  logic        dbg_sticky_div     /*verilator public_flat*/;
  logic        round_up           /*verilator public_flat*/;

  logic        dbg_unused = &{
			      dbg_raw_div_full,
			      dbg_q25,
			      dbg_lz_q,
			      dbg_q_norm,
			      dbg_q_div,
			      dbg_m,
			      dbg_guard_div,
   			      dbg_sticky_div,
			      round_up
			      };
   

  // unpack
  logic sign_a, sign_b, sign_z;
  logic [7:0] exp_a, exp_b;
  logic [22:0] frac_a, frac_b;
  logic is_zero_a, is_zero_b, is_inf_a, is_inf_b, is_nan_a, is_nan_b;

  assign sign_a = a[31];
  assign sign_b = b[31];
  assign exp_a = a[30:23];
  assign exp_b = b[30:23];
  assign frac_a = a[22:0];
  assign frac_b = b[22:0];

  assign is_zero_a = (exp_a == 0 && frac_a == 0);
  assign is_zero_b = (exp_b == 0 && frac_b == 0);
  assign is_inf_a = (exp_a == 8'hff && frac_a == 0);
  assign is_inf_b = (exp_b == 8'hff && frac_b == 0);
  assign is_nan_a = (exp_a == 8'hff && frac_a != 0);
  assign is_nan_b = (exp_b == 8'hff && frac_b != 0);

  assign sign_z = sign_a ^ sign_b;

  // count leading zeros
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

  // add function to count leading zeros in 50-bit quotient
  function automatic [5:0] count_lz50(input logic [49:0] mant);
    logic [5:0] i;
    begin
      count_lz50 = 6'd50;
      // count leading zeros with 6-bit index wrap
      for (i = 6'd49; i != 6'd63; i = i - 6'd1) begin
        if (mant[i]) begin
          // subtract with explicit 6-bit result
          count_lz50 = 6'd49 - i;
          break;
        end
      end
    end
  endfunction

  // normalize mantissas
  logic [23:0] norm_a, norm_b;
  logic signed [9:0] exp_unbias;
  // leading zero counts for subnormals
  logic [4:0] lz_a, lz_b;
  always_comb begin
    // default leading-zero counts for normalization
    lz_a   = (exp_a == 0) ? count_lz({1'b0, frac_a}) : 5'd0;
    lz_b   = (exp_b == 0) ? count_lz({1'b0, frac_b}) : 5'd0;
    // normalize operands
    norm_a = (exp_a == 0) ? ({1'b0, frac_a} << lz_a) : {1'b1, frac_a};
    norm_b = (exp_b == 0) ? ({1'b0, frac_b} << lz_b) : {1'b1, frac_b};
    // compute unbiased exponent with subnormal adjustment
    if (is_zero_a || is_nan_a || is_nan_b || is_inf_b || is_zero_b) begin
      exp_unbias = 0;
    end else begin
      exp_unbias = $signed({2'b00, (exp_a != 0 ? exp_a : 8'd1)}) - $signed(
          {2'b00, (exp_b != 0 ? exp_b : 8'd1)}) - $signed({5'd0, lz_a}) + $signed({5'd0, lz_b});
    end
  end

  // mantissa division (restoring) + guard/sticky: 50-bit dividend to get 23+2 bits precision
  function automatic [50:0] div_mant(input logic [49:0] num, input logic [23:0] den);
    integer i;
    reg [49:0] q;
    reg [24:0] r;
    logic [24:0] den_ext;
    reg sticky;
    begin
      r = 0;
      q = 0;
      sticky = 0;
      den_ext = {1'b0, den};
      for (i = 49; i >= 0; i = i - 1) begin
        r = {r[23:0], num[i]};
        if (r >= den_ext) begin
          r = r - den_ext;
          q[i] = 1;
        end else begin
          q[i] = 0;
        end
      end
      sticky   = |r;
      div_mant = {sticky, q};  // sticky + 50-bit quotient
    end
  endfunction

  // declare internal division signals
  logic [49:0] opa_div;  // numerator shifted for precision (24 bits mantissa + 26 guard bits)
  logic [23:0] opb_div;  // denominator mantissa
  logic [50:0] raw_div;  // sticky (bit50) + 50-bit quotient
  logic [49:0] q_full;  // 50-bit quotient from divider
  logic [49:0] q_norm;
  logic [23:0] q_div;  // hidden + 23-bit fraction
  logic guard_div;
  logic round_div;
  logic sticky_div;
  // dynamic normalization intermediate signals
  logic sticky_raw_div;  // raw divider sticky bit
  logic [5:0] lz_q;  // leading zero count of raw quotient
  logic [49:0] shifted_q;  // normalized 50-bit quotient
  logic [24:0] q25;  // temp pre-rounded mantissa + guard bit
  logic [24:0] m;  // temporary mantissa for subnormal normalization

  // rounding and normalization signals
  logic [23:0] mant_rnd_div;  // rounded mantissa
  logic signed [9:0] exp_sum;  // biased exponent after normalization
  logic [24:0] sum_expr;  // intermediate sum for rounding carry
  logic [47:0] mant_shift;  // for subnormal result shifting
  // subnormal rounding intermediate signals
  integer S;
  logic [46:0] mant_ext;
  logic guard_s, round_s, sticky_s;
  logic [22:0] mant_res;
  logic        round_up_s;
  logic [50:0] frac_s;  // combined shifted quotient + sticky
  logic [23:0] mant_rounded;  // intermediate rounded mantissa

  // result exponent
  logic [ 7:0] exp_z;
  // intermediate normalization flag (used)
  logic        norm1;
  // dummy to suppress unused-signal warnings
  logic        dummy_unused;

  // main comb logic
  always_comb begin
    // default for dummy, flags, and exp_sum to avoid latches
    dummy_unused = '0;
    norm1        = '0;
    exp_sum      = '0;
    q25          = '0;
    // default internal signals
    raw_div          = '0;
    opa_div          = '0;
    opb_div          = '0;
    q_div            = '0;
    guard_div        = '0;
    round_div        = '0;
    sticky_div       = '0;
    q_full           = '0;
    q_norm           = '0;
    sum_expr         = '0;
    mant_rnd_div     = '0;
    mant_shift       = '0;
    exp_z            = '0;
    // default dynamic-norm signals to prevent latches
    sticky_raw_div   = '0;
    round_up         = '0;
    lz_q             = '0;
    shifted_q        = '0;
    m                = '0;
    // subnormal defaults
    S                = '0;
    mant_res         = '0;
    guard_s          = '0;
    round_s          = '0;
    sticky_s         = '0;
    round_up_s       = '0;
    frac_s           = '0;
    mant_rounded     = '0;
    dbg_q_div        = '0;
    dbg_guard_div    = '0;
    dbg_sticky_div   = '0;
    dbg_raw_div_full = '0;
    dbg_q25          = '0;
    dbg_m            = '0;
    dbg_lz_q         = '0;
    dbg_q_norm       = '0;
    // default exception flags
    exc_invalid      = '0;
    exc_divzero      = '0;
    exc_overflow     = '0;
    exc_underflow    = '0;
    exc_inexact      = '0;
    // special cases: inf, zero, NaN
    if (is_nan_a || is_nan_b) begin
      // propagate NaN: invalid only for signaling NaNs
      exc_invalid = ((is_nan_a && frac_a[22]==1'b0) ||
                     (is_nan_b && frac_b[22]==1'b0)) ? 1'b1 : 1'b0;
      // propagate a quiet NaN payload from first NaN operand
      if (is_nan_a) y = {sign_a, 8'hff, 1'b1, frac_a[21:0]};
      else y = {sign_b, 8'hff, 1'b1, frac_b[21:0]};
    end else if (is_inf_a && is_inf_b) begin
      // inf/inf invalid
      exc_invalid = 1;
      y = 32'h7fc00000;
    end else if (is_inf_a) begin
      y = {sign_z, 8'hff, 23'd0};
    end else if (is_zero_a && is_zero_b) begin
      // 0/0 invalid
      exc_invalid = 1'b1;
      y = 32'h7fc00000;
    end else if (is_inf_b) begin
      // finite / inf => zero
      y = {sign_z, 8'd0, 23'd0};
    end else if (is_zero_a && !is_zero_b) begin
      y = {sign_z, 8'd0, 23'd0};
    end else if (is_zero_b) begin
      // finite / 0 => divzero
      y = {sign_z, 8'hff, 23'd0};
      exc_divzero = 1'b1;
    end else begin
      // normalized division with post-div normalization and rounding
      // prepare operands for extended division
      // mantissa division (restoring) and dynamic normalization
      // shift numerator to align for 23-bit mantissa + guard + round bits (total 25 extra bits)
      opa_div          = {norm_a, 25'd0, 1'b0};
      opb_div          = norm_b;
      raw_div          = div_mant(opa_div, opb_div);
      q_full           = raw_div[49:0];
      sticky_raw_div   = raw_div[50];
      lz_q             = count_lz50(q_full);
      q_norm           = q_full << lz_q;
      exp_sum          = exp_unbias + 10'sd150 - $signed({4'd0, lz_q});
      // extract mantissa and rounding bits
      q_div            = {q_norm[49], q_norm[48:26]};
      guard_div        = q_norm[25];
      round_div        = q_norm[24];
      sticky_div       = sticky_raw_div | |q_norm[23:0];
      // debug outputs
      dbg_raw_div_full = raw_div;
      dbg_q_div        = q_div;
      dbg_guard_div    = guard_div;
      dbg_sticky_div   = sticky_div;
      dbg_q25          = q_norm[49:25];
      // dbg_m will be assigned after computing m
      // compute round-to-nearest-even sum
      round_up         = guard_div & (round_div | sticky_div | q_div[0]);
      sum_expr         = {1'b0, q_div} + {{24{1'b0}}, round_up};
      m                = sum_expr;  // debug: pre-rounded mantissa with carry bit
      dbg_m            = m;  // capture m in debug output
      dbg_lz_q         = lz_q;
      dbg_q_norm       = q_norm;
      // handle rounding carry-out
      if (sum_expr[24]) begin
        mant_rnd_div = sum_expr[24:1];
        exp_sum      = exp_sum + 10'sd1;
      end else begin
        mant_rnd_div = sum_expr[23:0];
      end
      // final overflow/underflow checks
      if (exp_sum > 10'sd254) begin
        // overflow: result too large -> infinity per IEEE754
        exc_overflow = 1'b1;
        exc_inexact  = 1'b1;
        y = {sign_z, 8'hff, 23'd0};
      end else if (exp_sum <= -10'sd24) begin
        // deep underflow: flush to zero and signal underflow & inexact per SoftFloat
        exc_underflow = 1'b1;
        exc_inexact   = 1'b1;
        y = {sign_z, 8'd0, 23'd0};
      end else if (exp_sum <= 10'sd0) begin  // gradual underflow to subnormals
         // gradual underflow to subnormal
         // compute shift count for subnormals per SoftFloat: 1 - exp_sum
         S = 1 - integer'(exp_sum);
         if (S > 50) S = 50;
         frac_s   = ({q_norm, sticky_raw_div}) >> S;
         mant_res = frac_s[49:27];
         guard_s  = frac_s[26];
         round_s  = frac_s[25];
         sticky_s = |frac_s[24:0];
         // subnormal result: round half-up on guard bit
         round_up_s    = guard_s;
         mant_rounded  = mant_res + {23'd0, round_up_s};
         // exceptions if any bits lost
         exc_inexact   = guard_s | round_s | sticky_s;
         exc_underflow = exc_inexact;
         // select result (normalize if carry into normal range)
         if (mant_rounded[23]) begin
           y = {sign_z, 8'd1, 23'd0};
         end else begin
           y = {sign_z, 8'd0, mant_rounded[22:0]};
         end
      end else begin
        exp_z = exp_sum[7:0];
        // inexact if any rounding bits set
        exc_inexact = guard_div || round_div || sticky_div;
        // underflow if result subnormal after rounding
        if (exp_z == 8'd0) exc_underflow = 1'b1;
        y = {sign_z, exp_z, mant_rnd_div[22:0]};
      end
    end
    // Post-process: ensure any subnormal result has correct flags
    if (!exc_invalid && !exc_divzero && !exc_overflow && y[30:23] == 8'd0) begin
      // Only signal underflow/inexact for subnormals if there was actual rounding
      // Check if any rounding occurred during computation
      if ((guard_div | round_div | sticky_div) ||
          (guard_s | round_s | sticky_s)) begin
        exc_underflow = 1'b1;
        exc_inexact   = 1'b1;
      end
    end
    // reference unused signals to suppress lint warnings
    dummy_unused = |shifted_q      // entire shifted_q vector
                   | |mant_shift     // entire mant_shift vector
                   | |mant_ext       // entire mant_ext vector
                   | frac_s[50]      // msb of frac_s
                   | mant_rounded[23];// msb of mant_rounded
  end

endmodule
