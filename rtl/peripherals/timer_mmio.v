module timer_mmio (
    input  wire        clk,
    input  wire        resetn,
    input  wire        valid,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output reg         ready,
    output reg  [31:0] rdata,
    output wire        irq
);
    reg [63:0] counter;
    reg [63:0] compare;
    reg        irq_enable;
    reg        irq_pending;

    assign irq = irq_enable && irq_pending;

    always @(posedge clk) begin
        ready <= 1'b0;

        if (!resetn) begin
            counter <= 64'd0;
            compare <= 64'd0;
            irq_enable <= 1'b0;
            irq_pending <= 1'b0;
            rdata <= 32'h00000000;
        end else begin
            counter <= counter + 64'd1;

            if ((compare != 64'd0) && (counter >= compare)) begin
                irq_pending <= 1'b1;
            end

            if (valid) begin
                ready <= 1'b1;

                case (addr[4:2])
                    3'd0: rdata <= counter[31:0];
                    3'd1: rdata <= counter[63:32];
                    3'd2: begin
                        rdata <= compare[31:0];
                        if (wstrb[0]) compare[7:0]   <= wdata[7:0];
                        if (wstrb[1]) compare[15:8]  <= wdata[15:8];
                        if (wstrb[2]) compare[23:16] <= wdata[23:16];
                        if (wstrb[3]) compare[31:24] <= wdata[31:24];
                    end
                    3'd3: begin
                        rdata <= compare[63:32];
                        if (wstrb[0]) compare[39:32] <= wdata[7:0];
                        if (wstrb[1]) compare[47:40] <= wdata[15:8];
                        if (wstrb[2]) compare[55:48] <= wdata[23:16];
                        if (wstrb[3]) compare[63:56] <= wdata[31:24];
                    end
                    3'd4: begin
                        rdata <= {30'd0, irq_enable, irq_pending};
                        if (wstrb[0]) begin
                            irq_pending <= irq_pending & ~wdata[0];
                            irq_enable <= wdata[1];
                        end
                    end
                    default: rdata <= 32'h00000000;
                endcase
            end
        end
    end
endmodule
