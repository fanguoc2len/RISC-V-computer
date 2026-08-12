module riscv_pc_soc #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer UART_BAUD = 115200,
    parameter integer BOOT_ROM_WORDS = 4096,
    parameter integer SRAM_WORDS = 16384,
    parameter integer USE_AXI = 1
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
    output wire        debug_ps2_valid,
    output reg  [7:0]  debug_uart_tx_char,
    output reg         debug_uart_tx_valid
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
    localparam [31:0] NPU_BASE       = 32'h2000_5000;
    localparam [31:0] CPU_IRQ_VECTOR = BOOT_ROM_BASE + 32'h0000_0010;
    localparam integer TIMER_IRQ_INDEX = 3;
    localparam [31:0] CPU_LATCHED_IRQ = ~(32'h1 << TIMER_IRQ_INDEX);
    localparam [31:0] BOOT_INFO_STATUS_ADDR = SRAM_BASE + 32'h0000_0014;
    localparam [17:0] BOOT_ROM_SEL   = BOOT_ROM_BASE[31:14];
    localparam [15:0] SRAM_SEL       = SRAM_BASE[31:16];
    localparam [28:0] UART_SEL       = UART_BASE[31:3];
    localparam [29:0] GPIO_SEL       = GPIO_BASE[31:2];
    localparam [26:0] TIMER_SEL      = TIMER_BASE[31:5];
    localparam [28:0] SPI_SEL        = SPI_BASE[31:3];
    localparam [28:0] PS2_SEL        = PS2_BASE[31:3];
    localparam [25:0] NPU_SEL        = NPU_BASE[31:6];

    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    wire        axi_awvalid;
    wire        axi_awready;
    wire [31:0] axi_awaddr;
    wire [2:0]  axi_awprot;
    wire        axi_wvalid;
    wire        axi_wready;
    wire [31:0] axi_wdata;
    wire [3:0]  axi_wstrb;
    wire        axi_bvalid;
    wire        axi_bready;
    wire [1:0]  axi_bresp;
    wire        axi_arvalid;
    wire        axi_arready;
    wire [31:0] axi_araddr;
    wire [2:0]  axi_arprot;
    wire        axi_rvalid;
    wire        axi_rready;
    wire [31:0] axi_rdata;
    wire [1:0]  axi_rresp;

    wire [31:0] rom_rdata;
    wire [31:0] ram_rdata;
    wire [31:0] uart_rdata;
    wire [31:0] gpio_rdata;
    wire [31:0] timer_rdata;
    wire [31:0] spi_rdata;
    wire [31:0] ps2_rdata;
    wire [31:0] npu_rdata;

    reg rom_ready;
    reg ram_ready;
    reg invalid_ready;
    reg [31:0] debug_boot_status_r;
    reg debug_bus_error_r;
    wire bus_error_event;

    // Keep address decode shallow: match fixed address bits instead of wide range compares.
    wire sel_rom   = mem_valid && (mem_addr[31:14] == BOOT_ROM_SEL);
    wire sel_ram   = mem_valid && (mem_addr[31:16] == SRAM_SEL);
    wire sel_uart  = mem_valid && (mem_addr[31:3]  == UART_SEL);
    wire sel_gpio  = mem_valid && (mem_addr[31:2]  == GPIO_SEL);
    wire sel_timer = mem_valid && (mem_addr[31:5]  == TIMER_SEL) && (mem_addr[4:2] <= 3'd5);
    wire sel_spi   = mem_valid && (mem_addr[31:3]  == SPI_SEL);
    wire sel_ps2   = mem_valid && (mem_addr[31:3]  == PS2_SEL);
    wire sel_npu   = mem_valid && (mem_addr[31:6]  == NPU_SEL);
    wire sel_none  = mem_valid && !(sel_rom || sel_ram || sel_uart || sel_gpio || sel_timer || sel_spi || sel_ps2 || sel_npu);
    wire mem_error = sel_none;

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
    wire        npu_ready;
    wire        pcpi_valid;
    wire [31:0] pcpi_insn;
    wire [31:0] pcpi_rs1;
    wire [31:0] pcpi_rs2;
    wire        pcpi_wr;
    wire [31:0] pcpi_rd;
    wire        pcpi_wait;
    wire        pcpi_ready;
    wire [31:0] cpu_irq =
        timer_irq ? (32'h1 << TIMER_IRQ_INDEX) : 32'h0000_0000;
    wire [31:0] cpu_eoi;

    // Bit 31 is a sticky local-bus/AXI decode-error indication. PicoRV32 has
    // no native bus-fault input, so the transaction completes while hardware
    // keeps the error observable for bring-up and diagnostics.
    assign debug_boot_status = {
        debug_boot_status_r[31] | debug_bus_error_r,
        debug_boot_status_r[30:0]
    };
    assign uart_rdata = uart_div_sel ? uart_div_do : uart_dat_do;

    assign mem_ready = uart_ready || gpio_ready || timer_ready || spi_ready || ps2_ready || npu_ready || rom_ready || ram_ready || invalid_ready;

    assign mem_rdata =
        uart_ready   ? uart_rdata   :
        gpio_ready   ? gpio_rdata   :
        timer_ready  ? timer_rdata  :
        spi_ready    ? spi_rdata    :
        ps2_ready    ? ps2_rdata    :
        npu_ready    ? npu_rdata    :
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
            debug_bus_error_r <= 1'b0;
            debug_uart_tx_char <= 8'h00;
            debug_uart_tx_valid <= 1'b0;
        end else begin
            rom_ready <= mem_valid && !mem_ready && sel_rom;
            ram_ready <= mem_valid && !mem_ready && sel_ram;
            invalid_ready <= mem_valid && !mem_ready && sel_none;
            debug_uart_tx_valid <= uart_dat_sel && mem_valid && mem_wstrb[0] && !uart_dat_wait;

            if (bus_error_event) begin
                debug_bus_error_r <= 1'b1;
            end

            if (mem_valid && !mem_ready && sel_ram && (mem_addr == BOOT_INFO_STATUS_ADDR)) begin
                if (mem_wstrb[0]) debug_boot_status_r[7:0] <= mem_wdata[7:0];
                if (mem_wstrb[1]) debug_boot_status_r[15:8] <= mem_wdata[15:8];
                if (mem_wstrb[2]) debug_boot_status_r[23:16] <= mem_wdata[23:16];
                if (mem_wstrb[3]) debug_boot_status_r[31:24] <= mem_wdata[31:24];
            end

            if (uart_dat_sel && mem_valid && mem_wstrb[0] && !uart_dat_wait) begin
                debug_uart_tx_char <= mem_wdata[7:0];
            end
        end
    end

    generate
        if (USE_AXI != 0) begin : gen_axi_cpu
            wire trap_unused;

            picorv32_axi4lite #(
                .PROGADDR_RESET  (BOOT_ROM_BASE),
                .PROGADDR_IRQ    (CPU_IRQ_VECTOR),
                .STACKADDR       (SRAM_BASE + SRAM_BYTES),
                .ENABLE_MUL      (1),
                .ENABLE_DIV      (1),
                .BARREL_SHIFTER  (1),
                .COMPRESSED_ISA  (1),
                .ENABLE_COUNTERS (1),
                .ENABLE_PCPI     (1),
                .ENABLE_IRQ      (1),
                .LATCHED_IRQ     (CPU_LATCHED_IRQ)
            ) cpu_i (
                .clk           (clk),
                .resetn        (resetn),
                .trap          (trap_unused),
                .axi_error     (bus_error_event),
                .m_axi_awvalid (axi_awvalid),
                .m_axi_awready (axi_awready),
                .m_axi_awaddr  (axi_awaddr),
                .m_axi_awprot  (axi_awprot),
                .m_axi_wvalid  (axi_wvalid),
                .m_axi_wready  (axi_wready),
                .m_axi_wdata   (axi_wdata),
                .m_axi_wstrb   (axi_wstrb),
                .m_axi_bvalid  (axi_bvalid),
                .m_axi_bready  (axi_bready),
                .m_axi_bresp   (axi_bresp),
                .m_axi_arvalid (axi_arvalid),
                .m_axi_arready (axi_arready),
                .m_axi_araddr  (axi_araddr),
                .m_axi_arprot  (axi_arprot),
                .m_axi_rvalid  (axi_rvalid),
                .m_axi_rready  (axi_rready),
                .m_axi_rdata   (axi_rdata),
                .m_axi_rresp   (axi_rresp),
                .pcpi_valid    (pcpi_valid),
                .pcpi_insn     (pcpi_insn),
                .pcpi_rs1      (pcpi_rs1),
                .pcpi_rs2      (pcpi_rs2),
                .pcpi_wr       (pcpi_wr),
                .pcpi_rd       (pcpi_rd),
                .pcpi_wait     (pcpi_wait),
                .pcpi_ready    (pcpi_ready),
                .irq           (cpu_irq),
                .eoi           (cpu_eoi)
            );

            axi4lite_to_native axi_slave_i (
                .clk           (clk),
                .resetn        (resetn),
                .s_axi_awvalid (axi_awvalid),
                .s_axi_awready (axi_awready),
                .s_axi_awaddr  (axi_awaddr),
                .s_axi_awprot  (axi_awprot),
                .s_axi_wvalid  (axi_wvalid),
                .s_axi_wready  (axi_wready),
                .s_axi_wdata   (axi_wdata),
                .s_axi_wstrb   (axi_wstrb),
                .s_axi_bvalid  (axi_bvalid),
                .s_axi_bready  (axi_bready),
                .s_axi_bresp   (axi_bresp),
                .s_axi_arvalid (axi_arvalid),
                .s_axi_arready (axi_arready),
                .s_axi_araddr  (axi_araddr),
                .s_axi_arprot  (axi_arprot),
                .s_axi_rvalid  (axi_rvalid),
                .s_axi_rready  (axi_rready),
                .s_axi_rdata   (axi_rdata),
                .s_axi_rresp   (axi_rresp),
                .mem_valid     (mem_valid),
                .mem_instr     (mem_instr),
                .mem_ready     (mem_ready),
                .mem_addr      (mem_addr),
                .mem_wdata     (mem_wdata),
                .mem_wstrb     (mem_wstrb),
                .mem_rdata     (mem_rdata),
                .mem_error     (mem_error)
            );
        end else begin : gen_native_cpu
            assign bus_error_event = mem_valid && mem_ready && mem_error;

            picorv32 #(
                .PROGADDR_RESET   (BOOT_ROM_BASE),
                .PROGADDR_IRQ     (CPU_IRQ_VECTOR),
                .STACKADDR        (SRAM_BASE + SRAM_BYTES),
                .ENABLE_MUL       (1),
                .ENABLE_DIV       (1),
                .BARREL_SHIFTER   (1),
                .COMPRESSED_ISA   (1),
                .ENABLE_COUNTERS  (1),
                .ENABLE_PCPI      (1),
                .ENABLE_IRQ       (1),
                .LATCHED_IRQ      (CPU_LATCHED_IRQ)
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
                .pcpi_valid (pcpi_valid),
                .pcpi_insn  (pcpi_insn),
                .pcpi_rs1   (pcpi_rs1),
                .pcpi_rs2   (pcpi_rs2),
                .pcpi_wr    (pcpi_wr),
                .pcpi_rd    (pcpi_rd),
                .pcpi_wait  (pcpi_wait),
                .pcpi_ready (pcpi_ready),
                .irq        (cpu_irq),
                .eoi        (cpu_eoi)
            );
        end
    endgenerate

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
        .irq_ack          (cpu_eoi[TIMER_IRQ_INDEX]),
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

    npu_mmio npu_i (
        .clk   (clk),
        .resetn(resetn),
        .valid (sel_npu && !mem_ready),
        .addr  (mem_addr - NPU_BASE),
        .wdata (mem_wdata),
        .wstrb (mem_wstrb),
        .ready (npu_ready),
        .rdata (npu_rdata)
    );

    pcpi_npu pcpi_npu_i (
        .pcpi_valid (pcpi_valid),
        .pcpi_insn  (pcpi_insn),
        .pcpi_rs1   (pcpi_rs1),
        .pcpi_rs2   (pcpi_rs2),
        .pcpi_wr    (pcpi_wr),
        .pcpi_rd    (pcpi_rd),
        .pcpi_wait  (pcpi_wait),
        .pcpi_ready (pcpi_ready)
    );
endmodule
