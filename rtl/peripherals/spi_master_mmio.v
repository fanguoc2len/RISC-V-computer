module spi_master_mmio (
    input  wire        clk,
    input  wire        resetn,
    input  wire        valid,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output reg         ready,
    output reg  [31:0] rdata,
    output wire        spi_cs_n,
    output reg         spi_sclk,
    output reg         spi_mosi,
    input  wire        spi_miso
);
    reg [15:0] clk_div;
    reg [15:0] div_count;
    reg [7:0]  tx_data;
    reg [7:0]  rx_data;
    reg [7:0]  rx_shift;
    reg [2:0]  bit_index;
    reg        busy;
    reg        done;
    reg        cs_hold_low;
    reg        half_phase;

    assign spi_cs_n = ~(busy || cs_hold_low);

    always @(posedge clk) begin
        ready <= 1'b0;

        if (!resetn) begin
            clk_div <= 16'd250;
            div_count <= 16'd0;
            tx_data <= 8'hFF;
            rx_data <= 8'h00;
            rx_shift <= 8'h00;
            bit_index <= 3'd0;
            busy <= 1'b0;
            done <= 1'b0;
            cs_hold_low <= 1'b0;
            half_phase <= 1'b0;
            spi_sclk <= 1'b0;
            spi_mosi <= 1'b1;
            rdata <= 32'h00000000;
        end else begin
            if (busy) begin
                if (div_count >= clk_div) begin
                    div_count <= 16'd0;

                    if (!half_phase) begin
                        half_phase <= 1'b1;
                        spi_sclk <= 1'b1;
                        rx_shift[bit_index] <= spi_miso;
                    end else begin
                        half_phase <= 1'b0;
                        spi_sclk <= 1'b0;

                        if (bit_index == 3'd0) begin
                            busy <= 1'b0;
                            done <= 1'b1;
                            rx_data <= rx_shift;
                            spi_mosi <= 1'b1;
                        end else begin
                            bit_index <= bit_index - 3'd1;
                            spi_mosi <= tx_data[bit_index - 3'd1];
                        end
                    end
                end else begin
                    div_count <= div_count + 16'd1;
                end
            end

            if (valid) begin
                ready <= 1'b1;

                case (addr[3:2])
                    2'd0: begin
                        rdata <= {clk_div, 12'd0, done, busy, cs_hold_low, 1'b0};

                        if (wstrb[2]) clk_div[7:0]   <= wdata[23:16];
                        if (wstrb[3]) clk_div[15:8]  <= wdata[31:24];

                        if (wstrb[0]) begin
                            cs_hold_low <= wdata[1];

                            if (wdata[3]) begin
                                done <= 1'b0;
                            end

                            if (wdata[0] && !busy) begin
                                busy <= 1'b1;
                                done <= 1'b0;
                                bit_index <= 3'd7;
                                half_phase <= 1'b0;
                                div_count <= 16'd0;
                                spi_sclk <= 1'b0;
                                spi_mosi <= tx_data[7];
                                rx_shift <= 8'h00;
                            end
                        end
                    end
                    2'd1: begin
                        rdata <= {24'd0, rx_data};

                        if (wstrb[0]) begin
                            tx_data <= wdata[7:0];
                        end
                    end
                    default: rdata <= 32'h00000000;
                endcase
            end
        end
    end
endmodule
