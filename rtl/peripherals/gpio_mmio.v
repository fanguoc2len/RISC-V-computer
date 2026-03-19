module gpio_mmio (
    input  wire        clk,
    input  wire        resetn,
    input  wire        valid,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output reg         ready,
    output reg  [31:0] rdata,
    output reg  [31:0] gpio_out
);
    always @(posedge clk) begin
        ready <= 1'b0;

        if (!resetn) begin
            gpio_out <= 32'h00000000;
            rdata <= 32'h00000000;
        end else if (valid) begin
            ready <= 1'b1;
            rdata <= gpio_out;

            if (wstrb[0]) gpio_out[7:0]   <= wdata[7:0];
            if (wstrb[1]) gpio_out[15:8]  <= wdata[15:8];
            if (wstrb[2]) gpio_out[23:16] <= wdata[23:16];
            if (wstrb[3]) gpio_out[31:24] <= wdata[31:24];
        end
    end
endmodule
