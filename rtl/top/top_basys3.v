module top_basys3 (
    input  wire        clk,
    input  wire        btnC,
    output wire [15:0] led,
    input  wire        RsRx,
    output wire        RsTx,
    output wire [3:0]  vgaRed,
    output wire [3:0]  vgaGreen,
    output wire [3:0]  vgaBlue,
    output wire        Hsync,
    output wire        Vsync,
    input  wire        PS2Clk,
    input  wire        PS2Data,
    output wire        sd_cs_n,
    output wire        sd_sclk,
    output wire        sd_mosi,
    input  wire        sd_miso
);
    reg [1:0] pixel_divider;
    wire resetn = ~btnC;
    wire pixel_clk = pixel_divider[1];
    wire [31:0] gpio_out;
    wire [31:0] debug_timer_lo;
    wire [7:0] debug_ps2_data;
    wire debug_ps2_valid;

    always @(posedge clk) begin
        if (!resetn) begin
            pixel_divider <= 2'b00;
        end else begin
            pixel_divider <= pixel_divider + 2'b01;
        end
    end

    riscv_pc_soc #(
        .CLK_FREQ_HZ (100_000_000),
        .UART_BAUD   (115200),
        .BOOT_ROM_WORDS (4096),
        .SRAM_WORDS  (16384)
    ) soc_i (
        .clk      (clk),
        .resetn   (resetn),
        .uart_rx  (RsRx),
        .uart_tx  (RsTx),
        .ps2_clk  (PS2Clk),
        .ps2_data (PS2Data),
        .spi_cs_n (sd_cs_n),
        .spi_sclk (sd_sclk),
        .spi_mosi (sd_mosi),
        .spi_miso        (sd_miso),
        .gpio_out        (gpio_out),
        .debug_timer_lo  (debug_timer_lo),
        .debug_ps2_data  (debug_ps2_data),
        .debug_ps2_valid (debug_ps2_valid)
    );

    vga_status_panel vga_i (
        .clk_pix   (pixel_clk),
        .resetn    (resetn),
        .accent    (gpio_out[7:0]),
        .led_value (gpio_out[15:0]),
        .timer_lo  (debug_timer_lo),
        .ps2_data  (debug_ps2_data),
        .ps2_valid (debug_ps2_valid),
        .hsync     (Hsync),
        .vsync     (Vsync),
        .red       (vgaRed),
        .green     (vgaGreen),
        .blue      (vgaBlue)
    );

    assign led = gpio_out[15:0];
endmodule
