module npu_mmio (
    input  wire        clk,
    input  wire        resetn,
    input  wire        valid,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output reg         ready,
    output reg  [31:0] rdata
);
    reg [31:0] vec_a_reg;
    reg [31:0] vec_b_reg;
    reg [31:0] result_reg;
    reg        done_reg;

    wire [31:0] dot4_result;

    npu_dot4_i8 dot4_i (
        .vec_a  (vec_a_reg),
        .vec_b  (vec_b_reg),
        .result (dot4_result)
    );

    always @(posedge clk) begin
        ready <= 1'b0;

        if (!resetn) begin
            vec_a_reg <= 32'h00000000;
            vec_b_reg <= 32'h00000000;
            result_reg <= 32'h00000000;
            done_reg <= 1'b0;
            rdata <= 32'h00000000;
        end else if (valid) begin
            ready <= 1'b1;

            case (addr[3:2])
                2'd0: begin
                    rdata <= {30'd0, done_reg, 1'b0};

                    if (wstrb[0]) begin
                        if (wdata[1]) begin
                            done_reg <= 1'b0;
                        end

                        if (wdata[0]) begin
                            result_reg <= dot4_result;
                            done_reg <= 1'b1;
                        end
                    end
                end
                2'd1: begin
                    rdata <= vec_a_reg;
                    if (wstrb[0]) vec_a_reg[7:0] <= wdata[7:0];
                    if (wstrb[1]) vec_a_reg[15:8] <= wdata[15:8];
                    if (wstrb[2]) vec_a_reg[23:16] <= wdata[23:16];
                    if (wstrb[3]) vec_a_reg[31:24] <= wdata[31:24];
                end
                2'd2: begin
                    rdata <= vec_b_reg;
                    if (wstrb[0]) vec_b_reg[7:0] <= wdata[7:0];
                    if (wstrb[1]) vec_b_reg[15:8] <= wdata[15:8];
                    if (wstrb[2]) vec_b_reg[23:16] <= wdata[23:16];
                    if (wstrb[3]) vec_b_reg[31:24] <= wdata[31:24];
                end
                2'd3: begin
                    rdata <= result_reg;
                end
                default: begin
                    rdata <= 32'h00000000;
                end
            endcase
        end
    end
endmodule
