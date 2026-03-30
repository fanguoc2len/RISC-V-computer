module riscv_pc_soc #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer UART_BAUD = 115200,
    parameter integer BOOT_ROM_WORDS = 4096,
    parameter integer SRAM_WORDS = 16384
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        uart_rx,
    output wire        uart_tx,
    input  wire        ps2_clk,
    input  wire        ps2_data,
    output wire        spi_cs_n,
    output wire        spi_sclk,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output wire [31:0] gpio_out,
    output wire [31:0] debug_timer_lo,
    output wire [31:0] debug_boot_status,
    output wire [7:0]  debug_ps2_data,
    output wire        debug_ps2_valid
);
    localparam [31:0] BOOT_ROM_BASE  = 32'h0000_0000;
    localparam [31:0] BOOT_ROM_BYTES = BOOT_ROM_WORDS * 4;
    localparam [31:0] SRAM_BASE      = 32'h1000_0000;
    localparam [31:0] SRAM_BYTES     = SRAM_WORDS * 4;
    localparam [31:0] UART_BASE      = 32'h2000_0000;
    localparam [31:0] GPIO_BASE      = 32'h2000_1000;
    localparam [31:0] TIMER_BASE     = 32'h2000_2000;
    localparam [31:0] SPI_BASE       = 32'h2000_3000;
    localparam [31:0] PS2_BASE       = 32'h2000_4000;
    localparam [31:0] BOOT_INFO_STATUS_ADDR = SRAM_BASE + 32'h0000_0014;
    localparam [17:0] BOOT_ROM_SEL   = BOOT_ROM_BASE[31:14];
    localparam [15:0] SRAM_SEL       = SRAM_BASE[31:16];
    localparam [28:0] UART_SEL       = UART_BASE[31:3];
    localparam [29:0] GPIO_SEL       = GPIO_BASE[31:2];
    localparam [26:0] TIMER_SEL      = TIMER_BASE[31:5];
    localparam [28:0] SPI_SEL        = SPI_BASE[31:3];
    localparam [28:0] PS2_SEL        = PS2_BASE[31:3];

    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    wire [31:0] rom_rdata;
    wire [31:0] ram_rdata;
    wire [31:0] uart_rdata;
    wire [31:0] gpio_rdata;
    wire [31:0] timer_rdata;
    wire [31:0] spi_rdata;
    wire [31:0] ps2_rdata;

    reg rom_ready;
    reg ram_ready;
    reg invalid_ready;
    reg [31:0] debug_boot_status_r;

    // Keep address decode shallow: match fixed address bits instead of wide range compares.
    wire sel_rom   = mem_valid && (mem_addr[31:14] == BOOT_ROM_SEL);
    wire sel_ram   = mem_valid && (mem_addr[31:16] == SRAM_SEL);
    wire sel_uart  = mem_valid && (mem_addr[31:3]  == UART_SEL);
    wire sel_gpio  = mem_valid && (mem_addr[31:2]  == GPIO_SEL);
    wire sel_timer = mem_valid && (mem_addr[31:5]  == TIMER_SEL) && (mem_addr[4:2] <= 3'd4);
    wire sel_spi   = mem_valid && (mem_addr[31:3]  == SPI_SEL);
    wire sel_ps2   = mem_valid && (mem_addr[31:3]  == PS2_SEL);
    wire sel_none  = mem_valid && !(sel_rom || sel_ram || sel_uart || sel_gpio || sel_timer || sel_spi || sel_ps2);

    wire [31:0] uart_div_do;
    wire [31:0] uart_dat_do;
    wire        uart_dat_wait;
    wire        uart_div_sel = sel_uart && (mem_addr[3:2] == 2'd0);
    wire        uart_dat_sel = sel_uart && (mem_addr[3:2] == 2'd1);
    wire        uart_ready   = uart_div_sel || (uart_dat_sel && !uart_dat_wait);

    wire        gpio_ready;
    wire        timer_ready;
    wire        timer_irq;
    wire        spi_ready;
    wire        ps2_ready;

    assign debug_boot_status = debug_boot_status_r;
    assign uart_rdata = uart_div_sel ? uart_div_do : uart_dat_do;

    assign mem_ready = uart_ready || gpio_ready || timer_ready || spi_ready || ps2_ready || rom_ready || ram_ready || invalid_ready;

    assign mem_rdata =
        uart_ready   ? uart_rdata   :
        gpio_ready   ? gpio_rdata   :
        timer_ready  ? timer_rdata  :
        spi_ready    ? spi_rdata    :
        ps2_ready    ? ps2_rdata    :
        rom_ready    ? rom_rdata    :
        ram_ready    ? ram_rdata    :
        invalid_ready ? 32'hDEAD_BEEF :
        32'h0000_0000;

    always @(posedge clk) begin
        if (!resetn) begin
            rom_ready <= 1'b0;
            ram_ready <= 1'b0;
            invalid_ready <= 1'b0;
            debug_boot_status_r <= 32'h0000_0000;
        end else begin
            rom_ready <= mem_valid && !mem_ready && sel_rom;
            ram_ready <= mem_valid && !mem_ready && sel_ram;
            invalid_ready <= mem_valid && !mem_ready && sel_none;

            if (mem_valid && !mem_ready && sel_ram && (mem_addr == BOOT_INFO_STATUS_ADDR)) begin
                if (mem_wstrb[0]) debug_boot_status_r[7:0] <= mem_wdata[7:0];
                if (mem_wstrb[1]) debug_boot_status_r[15:8] <= mem_wdata[15:8];
                if (mem_wstrb[2]) debug_boot_status_r[23:16] <= mem_wdata[23:16];
                if (mem_wstrb[3]) debug_boot_status_r[31:24] <= mem_wdata[31:24];
            end
        end
    end

    picorv32 #(
        .PROGADDR_RESET   (BOOT_ROM_BASE),
        .PROGADDR_IRQ     (BOOT_ROM_BASE),
        .STACKADDR        (SRAM_BASE + SRAM_BYTES),
        .ENABLE_MUL       (1),
        .ENABLE_DIV       (1),
        .BARREL_SHIFTER   (1),
        .COMPRESSED_ISA   (1),
        .ENABLE_COUNTERS  (1),
        .ENABLE_IRQ       (0)
    ) cpu_i (
        .clk        (clk),
        .resetn     (resetn),
        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_ready  (mem_ready),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_rdata  (mem_rdata),
        .irq        (32'h0000_0000)
    );

    boot_rom #(
        .WORDS   (BOOT_ROM_WORDS),
        .MEMFILE ("bootrom.mem")
    ) boot_rom_i (
        .clk   (clk),
        .addr  (mem_addr - BOOT_ROM_BASE),
        .rdata (rom_rdata)
    );

    unified_sram #(
        .WORDS (SRAM_WORDS)
    ) sram_i (
        .clk   (clk),
        .wen   ((mem_valid && !mem_ready && sel_ram) ? mem_wstrb : 4'b0000),
        .addr  (mem_addr - SRAM_BASE),
        .wdata (mem_wdata),
        .rdata (ram_rdata)
    );

    simpleuart #(
        .DEFAULT_DIV (CLK_FREQ_HZ / UART_BAUD)
    ) uart_i (
        .clk          (clk),
        .resetn       (resetn),
        .ser_tx       (uart_tx),
        .ser_rx       (uart_rx),
        .reg_div_we   (uart_div_sel ? mem_wstrb : 4'b0000),
        .reg_div_di   (mem_wdata),
        .reg_div_do   (uart_div_do),
        .reg_dat_we   (uart_dat_sel ? mem_wstrb[0] : 1'b0),
        .reg_dat_re   (uart_dat_sel && (mem_wstrb == 4'b0000)),
        .reg_dat_di   (mem_wdata),
        .reg_dat_do   (uart_dat_do),
        .reg_dat_wait (uart_dat_wait)
    );

    gpio_mmio gpio_i (
        .clk      (clk),
        .resetn   (resetn),
        .valid    (sel_gpio && !mem_ready),
        .wdata    (mem_wdata),
        .wstrb    (mem_wstrb),
        .ready    (gpio_ready),
        .rdata    (gpio_rdata),
        .gpio_out (gpio_out)
    );

    timer_mmio timer_i (
        .clk              (clk),
        .resetn           (resetn),
        .valid            (sel_timer && !mem_ready),
        .addr             (mem_addr - TIMER_BASE),
        .wdata            (mem_wdata),
        .wstrb            (mem_wstrb),
        .ready            (timer_ready),
        .rdata            (timer_rdata),
        .irq              (timer_irq),
        .debug_counter_lo (debug_timer_lo)
    );

    spi_master_mmio spi_i (
        .clk      (clk),
        .resetn   (resetn),
        .valid    (sel_spi && !mem_ready),
        .addr     (mem_addr - SPI_BASE),
        .wdata    (mem_wdata),
        .wstrb    (mem_wstrb),
        .ready    (spi_ready),
        .rdata    (spi_rdata),
        .spi_cs_n (spi_cs_n),
        .spi_sclk (spi_sclk),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso)
    );

    ps2_keyboard_mmio ps2_i (
        .clk            (clk),
        .resetn         (resetn),
        .valid          (sel_ps2 && !mem_ready),
        .addr           (mem_addr - PS2_BASE),
        .wdata          (mem_wdata),
        .wstrb          (mem_wstrb),
        .ready          (ps2_ready),
        .rdata          (ps2_rdata),
        .ps2_clk        (ps2_clk),
        .ps2_data       (ps2_data),
        .debug_rx_data  (debug_ps2_data),
        .debug_rx_valid (debug_ps2_valid)
    );
endmodule
