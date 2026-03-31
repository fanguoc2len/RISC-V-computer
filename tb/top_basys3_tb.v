`timescale 1ns / 1ps

module top_basys3_tb;
    localparam integer CLK_FREQ_HZ = 100_000_000;
    localparam integer UART_BAUD = 115200;
    localparam integer UART_BIT_CLKS = CLK_FREQ_HZ / UART_BAUD;
    localparam integer PS2_HALF_CLKS = 200;
    localparam integer SPI_SIM_CLK_DIV = 8;
    localparam integer BOOT_WAIT_CLKS = 15_000_000;
    localparam integer BOOT_HEADER_BYTES = 32;
    localparam integer SPI_IMAGE_MAX_BYTES = 8192;
    localparam [31:0] BOOT_INFO_MAGIC = 32'h49425652;
    localparam [31:0] NPU_DEMO_EXPECT = 32'h00000032;
    localparam [31:0] NPU_VEC16_EXPECT = 32'hFFFFFF5C;
    localparam [31:0] NPU_MAT4_EXPECT0 = 32'h00000032;
    localparam [31:0] NPU_MAT4_EXPECT1 = 32'hFFFFFFFC;
    localparam [31:0] NPU_MAT4_EXPECT2 = 32'hFFFFFFCE;
    localparam [31:0] NPU_MAT4_EXPECT3 = 32'h000000E2;
    localparam integer TEXT_COLS = 80;
    localparam integer TEXT_ROWS = 29;
    localparam integer TEXT_DEPTH = TEXT_COLS * TEXT_ROWS;

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
    integer uart_rx_count;
    integer prompt_count;
    integer spi_sclk_posedge_count;
    integer spi_byte_index;
    integer boot_ok_count;
    integer help_reply_count;
    integer screen_scan_idx;
    integer app_help_count;
    integer spi_mem_init_idx;
    reg last_uart_tx;
    reg last_hsync;
    reg uart_mon_read;
    reg uart_mon_valid_prev;
    reg [7:0] uart_last_byte;
    reg [31:0] uart_shift4;
    reg [39:0] uart_shift5;
    reg [47:0] uart_shift6;
    reg [55:0] uart_shift7;
    reg [63:0] uart_shift8;
    reg [71:0] uart_shift9;
    reg [7:0] spi_shift_reg;
    reg [7:0] spi_image_mem [0:SPI_IMAGE_MAX_BYTES-1];
    reg spi_xfer_active;
    reg banner_seen;
    reg help_reply_seen;
    reg led_zero_msg_seen;
    reg boot_ok_seen;
    reg ps2_echo_seen;
    reg ps2_ok_seen;
    reg ps2_ascii_seen;
    reg info_reply_seen;
    reg status_reply_seen;
    reg mem_dump_seen;
    reg time_reply_seen;
    reg ram_reply_seen;
    reg npu_reply_seen;
    reg pcpi_reply_seen;
    reg vec16_reply_seen;
    reg mat_reply_seen;
    reg app_info_seen;
    reg app_go_seen;
    reg app_banner_seen;
    reg app_help_seen;
    reg app_npu_ok_seen;
    reg app_mat_ok_seen;
    reg go_command_sent;
    reg console_banner_seen;
    reg console_help_seen;
    reg console_prompt_seen;
    reg console_mat_seen;
    reg console_mat_r3_seen;

    wire uart_mon_tx_unused;
    wire [31:0] uart_mon_div_do;
    wire [31:0] uart_mon_dat_do;
    wire uart_mon_dat_wait;

    task automatic uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            if (data >= 8'h20 && data <= 8'h7E) begin
                $display("TB SEND UART byte 0x%02x ('%c') at time %0t.", data, data, $time);
            end else begin
                $display("TB SEND UART byte 0x%02x at time %0t.", data, $time);
            end

            RsRx = 1'b0;
            repeat (UART_BIT_CLKS) @(posedge clk);

            for (i = 0; i < 8; i = i + 1) begin
                RsRx = data[i];
                repeat (UART_BIT_CLKS) @(posedge clk);
            end

            RsRx = 1'b1;
            repeat (UART_BIT_CLKS) @(posedge clk);
            repeat (UART_BIT_CLKS) @(posedge clk);
        end
    endtask

    task automatic wait_for_prompt;
        input integer target_count;
        input integer max_cycles;
        integer i;
        begin
            for (i = 0; i < max_cycles && prompt_count < target_count; i = i + 1) begin
                @(posedge clk);
            end

            if (prompt_count < target_count) begin
                $display("FAIL: Prompt count did not reach %0d within %0d cycles.", target_count, max_cycles);
                $finish;
            end
        end
    endtask

    task automatic ps2_send_byte;
        input [7:0] data;
        reg parity;
        integer i;
        begin
            $display("TB SEND PS/2 byte 0x%02x at time %0t.", data, $time);
            parity = ~(^data);

            PS2Clk = 1'b1;
            PS2Data = 1'b1;
            repeat (PS2_HALF_CLKS * 4) @(posedge clk);

            PS2Data = 1'b0;
            repeat (PS2_HALF_CLKS) @(posedge clk);
            PS2Clk = 1'b0;
            repeat (PS2_HALF_CLKS) @(posedge clk);
            PS2Clk = 1'b1;
            repeat (PS2_HALF_CLKS) @(posedge clk);

            for (i = 0; i < 8; i = i + 1) begin
                PS2Data = data[i];
                repeat (PS2_HALF_CLKS) @(posedge clk);
                PS2Clk = 1'b0;
                repeat (PS2_HALF_CLKS) @(posedge clk);
                PS2Clk = 1'b1;
                repeat (PS2_HALF_CLKS) @(posedge clk);
            end

            PS2Data = parity;
            repeat (PS2_HALF_CLKS) @(posedge clk);
            PS2Clk = 1'b0;
            repeat (PS2_HALF_CLKS) @(posedge clk);
            PS2Clk = 1'b1;
            repeat (PS2_HALF_CLKS) @(posedge clk);

            PS2Data = 1'b1;
            repeat (PS2_HALF_CLKS) @(posedge clk);
            PS2Clk = 1'b0;
            repeat (PS2_HALF_CLKS) @(posedge clk);
            PS2Clk = 1'b1;
            repeat (PS2_HALF_CLKS * 2) @(posedge clk);
        end
    endtask

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

    // External UART monitor for simulation-only checking of the boot ROM byte stream.
    simpleuart #(
        .DEFAULT_DIV (CLK_FREQ_HZ / UART_BAUD)
    ) uart_mon (
        .clk          (clk),
        .resetn       (~btnC),
        .ser_tx       (uart_mon_tx_unused),
        .ser_rx       (RsTx),
        .reg_div_we   (4'b0000),
        .reg_div_di   (32'h0000_0000),
        .reg_div_do   (uart_mon_div_do),
        .reg_dat_we   (1'b0),
        .reg_dat_re   (uart_mon_read),
        .reg_dat_di   (32'h0000_0000),
        .reg_dat_do   (uart_mon_dat_do),
        .reg_dat_wait (uart_mon_dat_wait)
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
        uart_rx_count = 0;
        prompt_count = 0;
        spi_sclk_posedge_count = 0;
        boot_ok_count = 0;
        help_reply_count = 0;
        last_uart_tx = 1'b1;
        last_hsync = 1'b1;
        app_help_count = 0;
        uart_mon_read = 1'b0;
        uart_mon_valid_prev = 1'b0;
        uart_last_byte = 8'h00;
        uart_shift4 = 32'h00000000;
        uart_shift5 = 40'h0000000000;
        uart_shift6 = 48'h000000000000;
        uart_shift7 = 56'h00000000000000;
        uart_shift8 = 64'h0000000000000000;
        uart_shift9 = 72'h000000000000000000;
        spi_shift_reg = 8'hFF;
        spi_xfer_active = 1'b0;
        spi_byte_index = 0;
        banner_seen = 1'b0;
        help_reply_seen = 1'b0;
        led_zero_msg_seen = 1'b0;
        boot_ok_seen = 1'b0;
        ps2_echo_seen = 1'b0;
        ps2_ok_seen = 1'b0;
        ps2_ascii_seen = 1'b0;
        info_reply_seen = 1'b0;
        status_reply_seen = 1'b0;
        mem_dump_seen = 1'b0;
        time_reply_seen = 1'b0;
        ram_reply_seen = 1'b0;
        npu_reply_seen = 1'b0;
        pcpi_reply_seen = 1'b0;
        vec16_reply_seen = 1'b0;
        mat_reply_seen = 1'b0;
        app_info_seen = 1'b0;
        app_go_seen = 1'b0;
        app_banner_seen = 1'b0;
        app_help_seen = 1'b0;
        app_npu_ok_seen = 1'b0;
        app_mat_ok_seen = 1'b0;
        go_command_sent = 1'b0;
        console_banner_seen = 1'b0;
        console_help_seen = 1'b0;
        console_prompt_seen = 1'b0;
        console_mat_seen = 1'b0;
        console_mat_r3_seen = 1'b0;

        for (spi_mem_init_idx = 0; spi_mem_init_idx < SPI_IMAGE_MAX_BYTES; spi_mem_init_idx = spi_mem_init_idx + 1) begin
            spi_image_mem[spi_mem_init_idx] = 8'hFF;
        end
        $readmemh("boot_image.hex", spi_image_mem);

        if (spi_image_mem[0] !== 8'h52 || spi_image_mem[1] !== 8'h56 ||
            spi_image_mem[2] !== 8'h50 || spi_image_mem[3] !== 8'h43) begin
            $display("FAIL: SPI image header was not loaded from boot_image.hex.");
            $finish;
        end

        $display("Starting top_basys3 smoke simulation...");

        repeat (20) @(posedge clk);
        btnC = 1'b0;
        repeat (4) @(posedge clk);
        dut.soc_i.spi_i.clk_div = SPI_SIM_CLK_DIV[15:0];
        dut.soc_i.spi_i.div_count = 16'd0;

        wait_for_prompt(2, BOOT_WAIT_CLKS);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h68);
        wait_for_prompt(3, 400000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h6C);
        wait_for_prompt(4, 400000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        spi_byte_index = 0;
        spi_xfer_active = 1'b0;
        spi_shift_reg = 8'hFF;
        sd_miso = 1'b1;
        uart_send_byte(8'h62);
        wait_for_prompt(5, BOOT_WAIT_CLKS);
        ps2_send_byte(8'h1C);
        wait_for_prompt(6, 400000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h6B);
        wait_for_prompt(7, 400000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        ps2_send_byte(8'h33);
        wait_for_prompt(8, 400000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h69);
        wait_for_prompt(9, 1000000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h6D);
        wait_for_prompt(10, 400000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h74);
        wait_for_prompt(11, 400000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h72);
        wait_for_prompt(12, 500000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h6E);
        wait_for_prompt(13, 500000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h70);
        wait_for_prompt(14, 500000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h76);
        wait_for_prompt(15, 800000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h78);
        wait_for_prompt(16, 1000000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        go_command_sent = 1'b1;
        uart_send_byte(8'h67);
        wait_for_prompt(17, 1200000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h68);
        wait_for_prompt(18, 600000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h6E);
        wait_for_prompt(19, 700000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h76);
        wait_for_prompt(20, 1200000);
        ps2_send_byte(8'h33);
        wait_for_prompt(21, 600000);
        repeat (2000000) @(posedge clk);

        if (!banner_seen) begin
            $display("WARN: Did not observe full RV32 banner at startup; continuing because prompt/command path is alive.");
        end

        if (!help_reply_seen) begin
            $display("FAIL: Did not observe help reply after sending 'h'.");
            $finish;
        end

        if (!led_zero_msg_seen) begin
            $display("FAIL: Did not observe LED=0 reply after sending 'l'.");
            $finish;
        end

        if (!boot_ok_seen || boot_ok_count < 2) begin
            $display("FAIL: Did not observe BOOT=OK twice (autoboot + 'b'). Count=%0d.", boot_ok_count);
            $finish;
        end

        if (!ps2_ok_seen) begin
            $display("FAIL: Did not observe PS2=OK reply after sending 'k'.");
            $finish;
        end

        if (!ps2_echo_seen) begin
            $display("FAIL: Did not observe PS/2 ASCII echo path for unsupported key 'a'.");
            $finish;
        end

        if (!ps2_ascii_seen) begin
            $display("FAIL: Did not observe PS/2 ASCII decode after sending 'k'.");
            $finish;
        end

        if (help_reply_count < 2) begin
            $display("FAIL: Did not observe keyboard-driven help reply. Count=%0d.", help_reply_count);
            $finish;
        end

        if (!info_reply_seen) begin
            $display("FAIL: Did not observe boot info reply after sending 'i'.");
            $finish;
        end

        if (!status_reply_seen) begin
            $display("FAIL: Did not observe boot status reply after sending 'i'.");
            $finish;
        end

        if (!mem_dump_seen) begin
            $display("FAIL: Did not observe memory dump reply after sending 'm'.");
            $finish;
        end

        if (!time_reply_seen) begin
            $display("FAIL: Did not observe timer reply after sending 't'.");
            $finish;
        end

        if (!ram_reply_seen) begin
            $display("FAIL: Did not observe SRAM self-test reply after sending 'r'.");
            $finish;
        end

        if (!npu_reply_seen) begin
            $display("FAIL: Did not observe MMIO NPU reply after sending 'n'.");
            $finish;
        end

        if (!pcpi_reply_seen) begin
            $display("FAIL: Did not observe PCPI NPU reply after sending 'p'.");
            $finish;
        end

        if (!vec16_reply_seen) begin
            $display("FAIL: Did not observe accumulated vec16 NPU reply after sending 'v'.");
            $finish;
        end

        if (!mat_reply_seen) begin
            $display("FAIL: Did not observe matvec4 NPU reply after sending 'x'.");
            $finish;
        end

        if (dut.soc_i.npu_i.result_reg !== NPU_MAT4_EXPECT0) begin
            $display("FAIL: MMIO NPU result register is 0x%08x instead of 0x%08x.",
                     dut.soc_i.npu_i.result_reg, NPU_MAT4_EXPECT0);
            $finish;
        end

        if (dut.soc_i.npu_i.mat_res1_reg !== NPU_MAT4_EXPECT1 ||
            dut.soc_i.npu_i.mat_res2_reg !== NPU_MAT4_EXPECT2 ||
            dut.soc_i.npu_i.mat_res3_reg !== NPU_MAT4_EXPECT3) begin
            $display("FAIL: MATVEC result registers are wrong: R1=0x%08x R2=0x%08x R3=0x%08x.",
                     dut.soc_i.npu_i.mat_res1_reg, dut.soc_i.npu_i.mat_res2_reg, dut.soc_i.npu_i.mat_res3_reg);
            $finish;
        end

        if (led[0] !== 1'b0) begin
            $display("FAIL: LED0 did not toggle low after 'l' command.");
            $finish;
        end

        if (dut.soc_i.sram_i.mem[0] !== BOOT_INFO_MAGIC ||
            dut.soc_i.sram_i.mem[1] !== {spi_image_mem[7], spi_image_mem[6], spi_image_mem[5], spi_image_mem[4]} ||
            dut.soc_i.sram_i.mem[2] !== {spi_image_mem[11], spi_image_mem[10], spi_image_mem[9], spi_image_mem[8]} ||
            dut.soc_i.sram_i.mem[3] !== {spi_image_mem[15], spi_image_mem[14], spi_image_mem[13], spi_image_mem[12]} ||
            dut.soc_i.sram_i.mem[4] !== {spi_image_mem[19], spi_image_mem[18], spi_image_mem[17], spi_image_mem[16]} ||
            dut.soc_i.sram_i.mem[5] !== 32'h00000001) begin
            $display("FAIL: Boot info block was not written as expected.");
            $display("      info[0]=0x%08x info[1]=0x%08x info[2]=0x%08x info[3]=0x%08x",
                     dut.soc_i.sram_i.mem[0], dut.soc_i.sram_i.mem[1],
                     dut.soc_i.sram_i.mem[2], dut.soc_i.sram_i.mem[3]);
            $display("      info[4]=0x%08x info[5]=0x%08x",
                     dut.soc_i.sram_i.mem[4], dut.soc_i.sram_i.mem[5]);
            $finish;
        end

        if (dut.soc_i.sram_i.mem[8] === 32'h00000000 || dut.soc_i.sram_i.mem[9] === 32'h00000000) begin
            $display("FAIL: SRAM payload does not look populated after boot.");
            $display("      mem[8]=0x%08x mem[9]=0x%08x",
                     dut.soc_i.sram_i.mem[8], dut.soc_i.sram_i.mem[9]);
            $finish;
        end

        if (!app_info_seen) begin
            $display("FAIL: Did not observe SRAM app boot-info marker 'I' after sending 'g'.");
            $finish;
        end

        if (!app_go_seen) begin
            $display("FAIL: Did not observe SRAM app UART marker after sending 'g'.");
            $finish;
        end

        if (!app_banner_seen) begin
            $display("FAIL: Did not observe RVOS/32 app banner after sending 'g'.");
            $finish;
        end

        if (!app_help_seen || app_help_count < 3) begin
            $display("FAIL: Did not observe app help text enough times (startup + UART + PS/2). Count=%0d.", app_help_count);
            $finish;
        end

        if (!app_npu_ok_seen) begin
            $display("FAIL: Did not observe APPNPU=OK reply inside the SRAM app.");
            $finish;
        end

        if (!app_mat_ok_seen) begin
            $display("FAIL: Did not observe APPMAT=OK reply inside the SRAM app.");
            $finish;
        end

        if (led[3:0] !== 4'hA) begin
            $display("FAIL: SRAM app did not drive LED pattern 0xA after 'g'.");
            $finish;
        end

        if (spi_sclk_posedge_count < ((BOOT_HEADER_BYTES + dut.soc_i.sram_i.mem[2]) * 8)) begin
            $display("FAIL: SPI SCLK toggled only %0d times; expected at least %0d for header + payload read.",
                     spi_sclk_posedge_count, (BOOT_HEADER_BYTES + dut.soc_i.sram_i.mem[2]) * 8);
            $finish;
        end

        if (hsync_toggle_count == 0) begin
            $display("FAIL: VGA HSYNC never toggled.");
            $finish;
        end

        for (screen_scan_idx = 0; screen_scan_idx <= (TEXT_DEPTH - 7); screen_scan_idx = screen_scan_idx + 1) begin
            if (dut.vga_i.text_ram[screen_scan_idx + 0] == 8'h52 &&
                dut.vga_i.text_ram[screen_scan_idx + 1] == 8'h56 &&
                dut.vga_i.text_ram[screen_scan_idx + 2] == 8'h4F &&
                dut.vga_i.text_ram[screen_scan_idx + 3] == 8'h53 &&
                dut.vga_i.text_ram[screen_scan_idx + 4] == 8'h2F &&
                dut.vga_i.text_ram[screen_scan_idx + 5] == 8'h33 &&
                dut.vga_i.text_ram[screen_scan_idx + 6] == 8'h32) begin
                console_banner_seen = 1'b1;
            end
        end

        for (screen_scan_idx = 0; screen_scan_idx <= (TEXT_DEPTH - 8); screen_scan_idx = screen_scan_idx + 1) begin
            if (dut.vga_i.text_ram[screen_scan_idx + 0] == 8'h43 &&
                dut.vga_i.text_ram[screen_scan_idx + 1] == 8'h4D &&
                dut.vga_i.text_ram[screen_scan_idx + 2] == 8'h44 &&
                dut.vga_i.text_ram[screen_scan_idx + 3] == 8'h53 &&
                dut.vga_i.text_ram[screen_scan_idx + 4] == 8'h3A) begin
                console_help_seen = 1'b1;
            end
        end

        for (screen_scan_idx = 0; screen_scan_idx <= (TEXT_DEPTH - 5); screen_scan_idx = screen_scan_idx + 1) begin
            if (dut.vga_i.text_ram[screen_scan_idx + 0] == 8'h41 &&
                dut.vga_i.text_ram[screen_scan_idx + 1] == 8'h50 &&
                dut.vga_i.text_ram[screen_scan_idx + 2] == 8'h50 &&
                dut.vga_i.text_ram[screen_scan_idx + 3] == 8'h3E &&
                dut.vga_i.text_ram[screen_scan_idx + 4] == 8'h20) begin
                console_prompt_seen = 1'b1;
            end
        end

        for (screen_scan_idx = 0; screen_scan_idx <= (TEXT_DEPTH - 9); screen_scan_idx = screen_scan_idx + 1) begin
            if (dut.vga_i.text_ram[screen_scan_idx + 0] == 8'h41 &&
                dut.vga_i.text_ram[screen_scan_idx + 1] == 8'h50 &&
                dut.vga_i.text_ram[screen_scan_idx + 2] == 8'h50 &&
                dut.vga_i.text_ram[screen_scan_idx + 3] == 8'h4D &&
                dut.vga_i.text_ram[screen_scan_idx + 4] == 8'h41 &&
                dut.vga_i.text_ram[screen_scan_idx + 5] == 8'h54 &&
                dut.vga_i.text_ram[screen_scan_idx + 6] == 8'h3D &&
                dut.vga_i.text_ram[screen_scan_idx + 7] == 8'h4F &&
                dut.vga_i.text_ram[screen_scan_idx + 8] == 8'h4B) begin
                console_mat_seen = 1'b1;
            end
        end

        for (screen_scan_idx = 0; screen_scan_idx <= (TEXT_DEPTH - 11); screen_scan_idx = screen_scan_idx + 1) begin
            if (dut.vga_i.text_ram[screen_scan_idx + 0] == 8'h52 &&
                dut.vga_i.text_ram[screen_scan_idx + 1] == 8'h33 &&
                dut.vga_i.text_ram[screen_scan_idx + 2] == 8'h3D &&
                dut.vga_i.text_ram[screen_scan_idx + 3] == 8'h30 &&
                dut.vga_i.text_ram[screen_scan_idx + 4] == 8'h30 &&
                dut.vga_i.text_ram[screen_scan_idx + 5] == 8'h30 &&
                dut.vga_i.text_ram[screen_scan_idx + 6] == 8'h30 &&
                dut.vga_i.text_ram[screen_scan_idx + 7] == 8'h30 &&
                dut.vga_i.text_ram[screen_scan_idx + 8] == 8'h30 &&
                dut.vga_i.text_ram[screen_scan_idx + 9] == 8'h45 &&
                dut.vga_i.text_ram[screen_scan_idx + 10] == 8'h32) begin
                console_mat_r3_seen = 1'b1;
            end
        end

        if (!console_banner_seen) begin
            $display("FAIL: VGA text console did not retain the RVOS/32 app banner.");
            $finish;
        end

        if (!console_help_seen) begin
            $display("FAIL: VGA text console did not retain the app help line.");
            $finish;
        end

        if (!console_prompt_seen) begin
            $display("FAIL: VGA text console did not retain the APP> prompt.");
            $finish;
        end

        if (!console_mat_seen) begin
            $display("FAIL: VGA text console did not retain the APPMAT=OK reply.");
            $finish;
        end

        if (!console_mat_r3_seen) begin
            $display("FAIL: VGA text console did not retain the tail of the app MAT result line (R3=000000E2).");
            $finish;
        end

        $display("PASS: smoke simulation completed.");
        $finish;
    end

    always #5 clk = ~clk;

    always @(posedge sd_sclk) begin
        if (!sd_cs_n) begin
            spi_sclk_posedge_count <= spi_sclk_posedge_count + 1;
        end
    end

    always @(negedge sd_cs_n or posedge sd_cs_n or negedge sd_sclk) begin
        if (sd_cs_n) begin
            sd_miso <= 1'b1;
            if (spi_xfer_active) begin
                spi_xfer_active <= 1'b0;
                spi_byte_index <= spi_byte_index + 1;
            end
        end else if (!spi_xfer_active) begin
            spi_xfer_active <= 1'b1;
            spi_shift_reg <= spi_image_mem[spi_byte_index];
            sd_miso <= (spi_image_mem[spi_byte_index] >= 8'h80);
        end else begin
            sd_miso <= spi_shift_reg[6];
            spi_shift_reg <= {spi_shift_reg[6:0], 1'b1};
        end
    end

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        uart_mon_read <= 1'b0;
        uart_mon_valid_prev <= uart_mon.recv_buf_valid;

        if (RsTx != last_uart_tx) begin
            uart_toggle_count <= uart_toggle_count + 1;
            last_uart_tx <= RsTx;
        end

        if (Hsync != last_hsync) begin
            hsync_toggle_count <= hsync_toggle_count + 1;
            last_hsync <= Hsync;
        end

        if (uart_mon.recv_buf_valid && !uart_mon_valid_prev) begin
            uart_rx_count <= uart_rx_count + 1;
            uart_last_byte <= uart_mon.recv_buf_data;
            uart_mon_read <= 1'b1;
            uart_shift4 <= {uart_shift4[23:0], uart_mon.recv_buf_data};
            uart_shift5 <= {uart_shift5[31:0], uart_mon.recv_buf_data};
            uart_shift6 <= {uart_shift6[39:0], uart_mon.recv_buf_data};
            uart_shift7 <= {uart_shift7[47:0], uart_mon.recv_buf_data};
            uart_shift8 <= {uart_shift8[55:0], uart_mon.recv_buf_data};
            uart_shift9 <= {uart_shift9[63:0], uart_mon.recv_buf_data};

            if (uart_mon.recv_buf_data == 8'h3E) begin
                prompt_count <= prompt_count + 1;
            end

            if ({uart_shift4[23:0], uart_mon.recv_buf_data} == {8'h52, 8'h56, 8'h33, 8'h32}) begin
                banner_seen <= 1'b1;
            end

            if ({uart_shift5[31:0], uart_mon.recv_buf_data} == {8'h43, 8'h4D, 8'h44, 8'h53, 8'h3A}) begin
                help_reply_seen <= 1'b1;
                help_reply_count <= help_reply_count + 1;
            end

            if ({uart_shift5[31:0], uart_mon.recv_buf_data} == {8'h4C, 8'h45, 8'h44, 8'h3D, 8'h30}) begin
                led_zero_msg_seen <= 1'b1;
            end

            if ({uart_shift7[47:0], uart_mon.recv_buf_data} == {8'h42, 8'h4F, 8'h4F, 8'h54, 8'h3D, 8'h4F, 8'h4B}) begin
                boot_ok_seen <= 1'b1;
                boot_ok_count <= boot_ok_count + 1;
                $display("INFO: UART text matched BOOT=OK at time %0t.", $time);
            end

            if ({uart_shift6[39:0], uart_mon.recv_buf_data} == {8'h50, 8'h53, 8'h32, 8'h3D, 8'h4F, 8'h4B}) begin
                ps2_ok_seen <= 1'b1;
                $display("INFO: UART text matched PS2=OK at time %0t.", $time);
            end

            if ({uart_shift7[47:0], uart_mon.recv_buf_data} == {8'h61, 8'h0D, 8'h0A, 8'h3F, 8'h0D, 8'h0A, 8'h3E}) begin
                ps2_echo_seen <= 1'b1;
                $display("INFO: UART text matched keyboard echo a->? at time %0t.", $time);
            end

            if ({uart_shift7[47:0], uart_mon.recv_buf_data} == {8'h41, 8'h53, 8'h43, 8'h49, 8'h49, 8'h3D, 8'h61}) begin
                ps2_ascii_seen <= 1'b1;
                $display("INFO: UART text matched ASCII=a at time %0t.", $time);
            end

            if ({uart_shift6[39:0], uart_mon.recv_buf_data} == {8'h45, 8'h4E, 8'h54, 8'h52, 8'h59, 8'h3D}) begin
                info_reply_seen <= 1'b1;
                $display("INFO: UART text matched ENTRY= at time %0t.", $time);
            end

            if ({uart_shift7[47:0], uart_mon.recv_buf_data} == {8'h53, 8'h54, 8'h41, 8'h54, 8'h55, 8'h53, 8'h3D}) begin
                status_reply_seen <= 1'b1;
                $display("INFO: UART text matched STATUS= at time %0t.", $time);
            end

            if ({uart_shift5[31:0], uart_mon.recv_buf_data} == {8'h41, 8'h50, 8'h50, 8'h30, 8'h3D}) begin
                mem_dump_seen <= 1'b1;
                $display("INFO: UART text matched APP0= at time %0t.", $time);
            end

            if ({uart_shift5[31:0], uart_mon.recv_buf_data} == {8'h54, 8'h49, 8'h4D, 8'h45, 8'h3D}) begin
                time_reply_seen <= 1'b1;
                $display("INFO: UART text matched TIME= at time %0t.", $time);
            end

            if ({uart_shift6[39:0], uart_mon.recv_buf_data} == {8'h52, 8'h41, 8'h4D, 8'h3D, 8'h4F, 8'h4B}) begin
                ram_reply_seen <= 1'b1;
                $display("INFO: UART text matched RAM=OK at time %0t.", $time);
            end

            if ({uart_shift6[39:0], uart_mon.recv_buf_data} == {8'h4E, 8'h50, 8'h55, 8'h3D, 8'h4F, 8'h4B}) begin
                npu_reply_seen <= 1'b1;
                $display("INFO: UART text matched NPU=OK at time %0t.", $time);
            end

            if ({uart_shift7[47:0], uart_mon.recv_buf_data} == {8'h50, 8'h43, 8'h50, 8'h49, 8'h3D, 8'h4F, 8'h4B}) begin
                pcpi_reply_seen <= 1'b1;
                $display("INFO: UART text matched PCPI=OK at time %0t.", $time);
            end

            if ({uart_shift6[39:0], uart_mon.recv_buf_data} == {8'h56, 8'h31, 8'h36, 8'h3D, 8'h4F, 8'h4B}) begin
                vec16_reply_seen <= 1'b1;
                $display("INFO: UART text matched V16=OK at time %0t.", $time);
            end

            if ({uart_shift6[39:0], uart_mon.recv_buf_data} == {8'h4D, 8'h41, 8'h54, 8'h3D, 8'h4F, 8'h4B}) begin
                mat_reply_seen <= 1'b1;
                $display("INFO: UART text matched MAT=OK at time %0t.", $time);
            end

            if (go_command_sent && uart_mon.recv_buf_data == 8'h49) begin
                app_info_seen <= 1'b1;
                $display("INFO: Observed SRAM app boot-info marker 'I' at time %0t.", $time);
            end

            if (go_command_sent && uart_mon.recv_buf_data == 8'h47) begin
                app_go_seen <= 1'b1;
                $display("INFO: Observed SRAM app UART marker 'G' at time %0t.", $time);
            end

            if (go_command_sent &&
                {uart_shift7[47:0], uart_mon.recv_buf_data} == {8'h52, 8'h56, 8'h4F, 8'h53, 8'h2F, 8'h33, 8'h32}) begin
                app_banner_seen <= 1'b1;
            end

            if (go_command_sent &&
                {uart_shift8[55:0], uart_mon.recv_buf_data} == {8'h41, 8'h50, 8'h50, 8'h43, 8'h4D, 8'h44, 8'h53, 8'h3A}) begin
                app_help_seen <= 1'b1;
                app_help_count <= app_help_count + 1;
            end

            if (go_command_sent &&
                {uart_shift9[63:0], uart_mon.recv_buf_data} == {8'h41, 8'h50, 8'h50, 8'h4E, 8'h50, 8'h55, 8'h3D, 8'h4F, 8'h4B}) begin
                app_npu_ok_seen <= 1'b1;
                $display("INFO: UART text matched APPNPU=OK at time %0t.", $time);
            end

            if (go_command_sent &&
                {uart_shift9[63:0], uart_mon.recv_buf_data} == {8'h41, 8'h50, 8'h50, 8'h4D, 8'h41, 8'h54, 8'h3D, 8'h4F, 8'h4B}) begin
                app_mat_ok_seen <= 1'b1;
                $display("INFO: UART text matched APPMAT=OK at time %0t.", $time);
            end

            $display("INFO: UART monitor received byte 0x%02x at time %0t.", uart_mon.recv_buf_data, $time);
        end
    end
endmodule
