module fp32_sqrt_comb (
    input  logic [31:0] a,      // IEEE754 single-precision input
    output logic [31:0] y       // IEEE754 single-precision output (sqrt(a))
);

    // Unpack input
    logic        sign;
    logic [7:0]  exp;
    logic [22:0] frac;
    logic [23:0] norm_frac;
    logic [7:0]  out_exp;
    logic [23:0] sqrt_frac;
    logic [31:0] result;

    // Special cases
    logic is_zero, is_inf, is_nan, is_neg;

    assign sign = a[31];
    assign exp  = a[30:23];
    assign frac = a[22:0];

    assign is_zero = (exp == 8'd0) && (frac == 23'd0);
    assign is_inf  = (exp == 8'hff) && (frac == 23'd0);
    assign is_nan  = (exp == 8'hff) && (frac != 23'd0);
    assign is_neg  = sign && !is_zero;

    // Normalize subnormal numbers
    logic [7:0] norm_exp;
    logic [23:0] norm_mant;
    always_comb begin
        if (exp == 8'd0) begin
            // Subnormal
            norm_exp  = 8'd1;
            norm_mant = {1'b0, frac};
        end else begin
            // Normalized
            norm_exp  = exp;
            norm_mant = {1'b1, frac};
        end
    end

    // Calculate sqrt exponent
    logic [8:0] exp_unbias;
    logic [8:0] sqrt_exp;
    always_comb begin
        exp_unbias = {1'b0, norm_exp} - 127;
        sqrt_exp   = (exp_unbias >> 1) + 127;
    end

    // Calculate sqrt mantissa using non-restoring algorithm (24bit)
    function automatic [23:0] sqrt24(input [23:0] op);
        integer i;
        reg [47:0] rem;
        reg [23:0] root;
        reg [25:0] test_div;
        begin
            rem = 0;
            root = 0;
            for (i = 0; i < 24; i = i + 1) begin
                rem = {rem[45:0], op[23-i], 1'b0};
                test_div = {root, 1'b1};
                if (rem[47:24] >= test_div) begin
                    rem[47:24] = rem[47:24] - test_div;
                    root = {root[22:0], 1'b1};
                end else begin
                    root = {root[22:0], 1'b0};
                end
            end
            sqrt24 = root;
        end
    endfunction

    always_comb begin
        sqrt_frac = '0;
        out_exp   = '0;
        if (is_nan || (is_neg && !is_zero)) begin
            // NaN or negative input (except -0)
            result = 32'h7fc00000;
        end else if (is_inf) begin
            // Infinity
            result = 32'h7f800000;
        end else if (is_zero) begin
            // Zero
            result = a;
        end else begin
            // Normal case
            sqrt_frac = sqrt24(norm_mant << (exp_unbias[0] ? 1 : 0));
            out_exp   = sqrt_exp[7:0];
            result = {1'b0, out_exp, sqrt_frac[22:0]};
        end
    end

    assign y = result;

endmodule