module ps2_keyboard_mmio (
    input  wire        clk,
    input  wire        resetn,
    input  wire        valid,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output reg         ready,
    output reg  [31:0] rdata,
    input  wire        ps2_clk,
    input  wire        ps2_data
);
    reg [2:0] ps2_clk_sync;
    reg [2:0] ps2_data_sync;
    reg [10:0] shift_reg;
    reg [3:0] bit_count;
    reg [7:0] rx_data;
    reg       rx_valid;
    reg       overflow;

    wire ps2_clk_fall = (ps2_clk_sync[2:1] == 2'b10);

    always @(posedge clk) begin
        ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};
        ps2_data_sync <= {ps2_data_sync[1:0], ps2_data};
        ready <= 1'b0;

        if (!resetn) begin
            shift_reg <= 11'd0;
            bit_count <= 4'd0;
            rx_data <= 8'd0;
            rx_valid <= 1'b0;
            overflow <= 1'b0;
            rdata <= 32'h00000000;
            ps2_clk_sync <= 3'b111;
            ps2_data_sync <= 3'b111;
        end else begin
            if (ps2_clk_fall) begin
                shift_reg <= {ps2_data_sync[2], shift_reg[10:1]};

                if (bit_count == 4'd10) begin
                    bit_count <= 4'd0;

                    // After 10 captured bits (start + 8 data + parity), the start bit
                    // sits in shift_reg[1] and the data byte in shift_reg[9:2].
                    if ((shift_reg[1] == 1'b0) && (ps2_data_sync[2] == 1'b1)) begin
                        if (rx_valid) begin
                            overflow <= 1'b1;
                        end
                        rx_data <= shift_reg[9:2];
                        rx_valid <= 1'b1;
                    end
                end else begin
                    bit_count <= bit_count + 4'd1;
                end
            end

            if (valid) begin
                ready <= 1'b1;

                case (addr[3:2])
                    2'd0: begin
                        rdata <= {24'd0, rx_data};
                        if (wstrb == 4'b0000) begin
                            rx_valid <= 1'b0;
                        end
                    end
                    2'd1: begin
                        rdata <= {30'd0, overflow, rx_valid};
                        if (wstrb[0]) begin
                            if (wdata[0]) rx_valid <= 1'b0;
                            if (wdata[1]) overflow <= 1'b0;
                        end
                    end
                    default: rdata <= 32'h00000000;
                endcase
            end
        end
    end
endmodule
