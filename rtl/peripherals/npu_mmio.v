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
    reg [31:0] mat_row1_reg;
    reg [31:0] mat_row2_reg;
    reg [31:0] mat_row3_reg;
    reg [31:0] mat_res1_reg;
    reg [31:0] mat_res2_reg;
    reg [31:0] mat_res3_reg;
    reg        done_reg;

    wire [31:0] dot4_result;
    wire [31:0] mat_row1_result;
    wire [31:0] mat_row2_result;
    wire [31:0] mat_row3_result;

    npu_dot4_i8 dot4_i (
        .vec_a  (vec_a_reg),
        .vec_b  (vec_b_reg),
        .result (dot4_result)
    );

    npu_dot4_i8 mat_row1_i (
        .vec_a  (vec_a_reg),
        .vec_b  (mat_row1_reg),
        .result (mat_row1_result)
    );

    npu_dot4_i8 mat_row2_i (
        .vec_a  (vec_a_reg),
        .vec_b  (mat_row2_reg),
        .result (mat_row2_result)
    );

    npu_dot4_i8 mat_row3_i (
        .vec_a  (vec_a_reg),
        .vec_b  (mat_row3_reg),
        .result (mat_row3_result)
    );

    always @(posedge clk) begin
        ready <= 1'b0;

        if (!resetn) begin
            vec_a_reg <= 32'h00000000;
            vec_b_reg <= 32'h00000000;
            result_reg <= 32'h00000000;
            mat_row1_reg <= 32'h00000000;
            mat_row2_reg <= 32'h00000000;
            mat_row3_reg <= 32'h00000000;
            mat_res1_reg <= 32'h00000000;
            mat_res2_reg <= 32'h00000000;
            mat_res3_reg <= 32'h00000000;
            done_reg <= 1'b0;
            rdata <= 32'h00000000;
        end else if (valid) begin
            ready <= 1'b1;

            case (addr[5:2])
                4'd0: begin
                    rdata <= {30'd0, done_reg, 1'b0};

                    if (wstrb[0]) begin
                        if (wdata[2]) begin
                            result_reg <= 32'h00000000;
                            mat_res1_reg <= 32'h00000000;
                            mat_res2_reg <= 32'h00000000;
                            mat_res3_reg <= 32'h00000000;
                            done_reg <= 1'b0;
                        end

                        if (wdata[1]) begin
                            done_reg <= 1'b0;
                        end

                        if (wdata[4]) begin
                            result_reg <= dot4_result;
                            mat_res1_reg <= mat_row1_result;
                            mat_res2_reg <= mat_row2_result;
                            mat_res3_reg <= mat_row3_result;
                            done_reg <= 1'b1;
                        end else if (wdata[0]) begin
                            result_reg <= wdata[3] ? (result_reg + dot4_result) : dot4_result;
                            done_reg <= 1'b1;
                        end
                    end
                end
                4'd1: begin
                    rdata <= vec_a_reg;
                    if (wstrb[0]) vec_a_reg[7:0] <= wdata[7:0];
                    if (wstrb[1]) vec_a_reg[15:8] <= wdata[15:8];
                    if (wstrb[2]) vec_a_reg[23:16] <= wdata[23:16];
                    if (wstrb[3]) vec_a_reg[31:24] <= wdata[31:24];
                end
                4'd2: begin
                    rdata <= vec_b_reg;
                    if (wstrb[0]) vec_b_reg[7:0] <= wdata[7:0];
                    if (wstrb[1]) vec_b_reg[15:8] <= wdata[15:8];
                    if (wstrb[2]) vec_b_reg[23:16] <= wdata[23:16];
                    if (wstrb[3]) vec_b_reg[31:24] <= wdata[31:24];
                end
                4'd3: begin
                    rdata <= result_reg;
                end
                4'd4: begin
                    rdata <= mat_row1_reg;
                    if (wstrb[0]) mat_row1_reg[7:0] <= wdata[7:0];
                    if (wstrb[1]) mat_row1_reg[15:8] <= wdata[15:8];
                    if (wstrb[2]) mat_row1_reg[23:16] <= wdata[23:16];
                    if (wstrb[3]) mat_row1_reg[31:24] <= wdata[31:24];
                end
                4'd5: begin
                    rdata <= mat_row2_reg;
                    if (wstrb[0]) mat_row2_reg[7:0] <= wdata[7:0];
                    if (wstrb[1]) mat_row2_reg[15:8] <= wdata[15:8];
                    if (wstrb[2]) mat_row2_reg[23:16] <= wdata[23:16];
                    if (wstrb[3]) mat_row2_reg[31:24] <= wdata[31:24];
                end
                4'd6: begin
                    rdata <= mat_row3_reg;
                    if (wstrb[0]) mat_row3_reg[7:0] <= wdata[7:0];
                    if (wstrb[1]) mat_row3_reg[15:8] <= wdata[15:8];
                    if (wstrb[2]) mat_row3_reg[23:16] <= wdata[23:16];
                    if (wstrb[3]) mat_row3_reg[31:24] <= wdata[31:24];
                end
                4'd7: begin
                    rdata <= mat_res1_reg;
                end
                4'd8: begin
                    rdata <= mat_res2_reg;
                end
                4'd9: begin
                    rdata <= mat_res3_reg;
                end
                default: begin
                    rdata <= 32'h00000000;
                end
            endcase
        end
    end
endmodule
