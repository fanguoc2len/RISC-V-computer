`timescale 1ns / 1ps

module top_basys3_tb;
    reg clk;
    reg btnC;
    reg RsRx;
    reg PS2Clk;
    reg PS2Data;
    reg sd_miso;

    wire [15:0] led;
    wire RsTx;
    wire [3:0] vgaRed;
    wire [3:0] vgaGreen;
    wire [3:0] vgaBlue;
    wire Hsync;
    wire Vsync;
    wire sd_cs_n;
    wire sd_sclk;
    wire sd_mosi;

    integer cycle_count;
    integer uart_toggle_count;
    integer hsync_toggle_count;
    reg last_uart_tx;
    reg last_hsync;

    top_basys3 dut (
        .clk     (clk),
        .btnC    (btnC),
        .led     (led),
        .RsRx    (RsRx),
        .RsTx    (RsTx),
        .vgaRed  (vgaRed),
        .vgaGreen(vgaGreen),
        .vgaBlue (vgaBlue),
        .Hsync   (Hsync),
        .Vsync   (Vsync),
        .PS2Clk  (PS2Clk),
        .PS2Data (PS2Data),
        .sd_cs_n (sd_cs_n),
        .sd_sclk (sd_sclk),
        .sd_mosi (sd_mosi),
        .sd_miso (sd_miso)
    );

    initial begin
        clk = 1'b0;
        btnC = 1'b1;
        RsRx = 1'b1;
        PS2Clk = 1'b1;
        PS2Data = 1'b1;
        sd_miso = 1'b1;
        cycle_count = 0;
        uart_toggle_count = 0;
        hsync_toggle_count = 0;
        last_uart_tx = 1'b1;
        last_hsync = 1'b1;

        $display("Starting top_basys3 smoke simulation...");

        repeat (20) @(posedge clk);
        btnC = 1'b0;

        repeat (20000) @(posedge clk);

        if (led[0] !== 1'b1) begin
            $display("FAIL: LED0 was not asserted by boot ROM.");
            $finish;
        end

        if (uart_toggle_count == 0) begin
            $display("FAIL: UART TX never toggled.");
            $finish;
        end

        if (hsync_toggle_count == 0) begin
            $display("FAIL: VGA HSYNC never toggled.");
            $finish;
        end

        $display("PASS: smoke simulation completed.");
        $finish;
    end

    always #5 clk = ~clk;

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;

        if (RsTx != last_uart_tx) begin
            uart_toggle_count <= uart_toggle_count + 1;
            last_uart_tx <= RsTx;
        end

        if (Hsync != last_hsync) begin
            hsync_toggle_count <= hsync_toggle_count + 1;
            last_hsync <= Hsync;
        end
    end
endmodule
