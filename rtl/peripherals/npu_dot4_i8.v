module npu_dot4_i8 (
    input  wire [31:0] vec_a,
    input  wire [31:0] vec_b,
    output wire [31:0] result
);
    function [31:0] dot4_packed_i8;
        input [31:0] lhs;
        input [31:0] rhs;
        reg signed [7:0] lhs0;
        reg signed [7:0] lhs1;
        reg signed [7:0] lhs2;
        reg signed [7:0] lhs3;
        reg signed [7:0] rhs0;
        reg signed [7:0] rhs1;
        reg signed [7:0] rhs2;
        reg signed [7:0] rhs3;
        reg signed [31:0] sum;
    begin
        lhs0 = lhs[7:0];
        lhs1 = lhs[15:8];
        lhs2 = lhs[23:16];
        lhs3 = lhs[31:24];
        rhs0 = rhs[7:0];
        rhs1 = rhs[15:8];
        rhs2 = rhs[23:16];
        rhs3 = rhs[31:24];
        sum = (lhs0 * rhs0) + (lhs1 * rhs1) + (lhs2 * rhs2) + (lhs3 * rhs3);
        dot4_packed_i8 = sum;
    end
    endfunction

    assign result = dot4_packed_i8(vec_a, vec_b);
endmodule
