module pcpi_npu (
    input  wire        pcpi_valid,
    input  wire [31:0] pcpi_insn,
    input  wire [31:0] pcpi_rs1,
    input  wire [31:0] pcpi_rs2,
    output wire        pcpi_wr,
    output wire [31:0] pcpi_rd,
    output wire        pcpi_wait,
    output wire        pcpi_ready
);
    wire insn_dot4;
    wire [31:0] dot4_result;

    assign insn_dot4 =
        pcpi_valid &&
        (pcpi_insn[6:0] == 7'b0001011) &&
        (pcpi_insn[14:12] == 3'b000) &&
        (pcpi_insn[31:25] == 7'b0101010);

    npu_dot4_i8 dot4_i (
        .vec_a  (pcpi_rs1),
        .vec_b  (pcpi_rs2),
        .result (dot4_result)
    );

    assign pcpi_wr = insn_dot4;
    assign pcpi_rd = insn_dot4 ? dot4_result : 32'h00000000;
    assign pcpi_wait = 1'b0;
    assign pcpi_ready = insn_dot4;
endmodule
