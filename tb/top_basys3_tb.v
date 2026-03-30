`timescale 1ns / 1ps

module top_basys3_tb;
    localparam integer CLK_FREQ_HZ = 100_000_000;
    localparam integer UART_BAUD = 115200;
    localparam integer UART_BIT_CLKS = CLK_FREQ_HZ / UART_BAUD;
    localparam integer PS2_HALF_CLKS = 200;
    localparam integer BOOT_HEADER_BYTES = 32;
    localparam integer BOOT_PAYLOAD_BYTES = 88;
    localparam [31:0] BOOT_INFO_MAGIC = 32'h49425652;
    localparam [31:0] NPU_DEMO_EXPECT = 32'h00000032;
    localparam integer PANEL_BG_X = 170;
    localparam integer PANEL_BG_Y = 36;
    localparam integer PANEL_LABEL_X = 29;
    localparam integer PANEL_LABEL_Y = 33;
    localparam integer PANEL_LED_DIGIT_X = 101;
    localparam integer PANEL_LED_DIGIT_Y = 33;
    localparam integer PANEL_STATUS_OK_X = 152;
    localparam integer PANEL_STATUS_OK_Y = 74;

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
    reg [7:0] spi_shift_reg;
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
    reg app_info_seen;
    reg app_go_seen;
    reg go_command_sent;
    reg panel_bg_seen;
    reg panel_label_seen;
    reg panel_led_zero_seen;
    reg panel_led_a_seen;
    reg panel_status_ok_seen;

    wire uart_mon_tx_unused;
    wire [31:0] uart_mon_div_do;
    wire [31:0] uart_mon_dat_do;
    wire uart_mon_dat_wait;

    function [7:0] spi_image_byte;
        input integer index;
        begin
            case (index)
                0: spi_image_byte = 8'h52;
                1: spi_image_byte = 8'h56;
                2: spi_image_byte = 8'h50;
                3: spi_image_byte = 8'h43;
                4: spi_image_byte = 8'h20;
                5: spi_image_byte = 8'h00;
                6: spi_image_byte = 8'h00;
                7: spi_image_byte = 8'h10;
                8: spi_image_byte = 8'h58;
                9: spi_image_byte = 8'h00;
                10: spi_image_byte = 8'h00;
                11: spi_image_byte = 8'h00;
                12: spi_image_byte = 8'h20;
                13: spi_image_byte = 8'h00;
                14: spi_image_byte = 8'h00;
                15: spi_image_byte = 8'h10;
                16: spi_image_byte = 8'hF2;
                17: spi_image_byte = 8'h83;
                18: spi_image_byte = 8'h8F;
                19: spi_image_byte = 8'h46;
                20: spi_image_byte = 8'h01;
                21: spi_image_byte = 8'h00;
                22: spi_image_byte = 8'h00;
                23: spi_image_byte = 8'h00;
                24: spi_image_byte = 8'h00;
                25: spi_image_byte = 8'h00;
                26: spi_image_byte = 8'h00;
                27: spi_image_byte = 8'h00;
                28: spi_image_byte = 8'h00;
                29: spi_image_byte = 8'h00;
                30: spi_image_byte = 8'h00;
                31: spi_image_byte = 8'h00;
                32: spi_image_byte = 8'hB7;
                33: spi_image_byte = 8'h02;
                34: spi_image_byte = 8'h00;
                35: spi_image_byte = 8'h10;
                36: spi_image_byte = 8'h03;
                37: spi_image_byte = 8'hA3;
                38: spi_image_byte = 8'h02;
                39: spi_image_byte = 8'h00;
                40: spi_image_byte = 8'hB7;
                41: spi_image_byte = 8'h53;
                42: spi_image_byte = 8'h42;
                43: spi_image_byte = 8'h49;
                44: spi_image_byte = 8'h93;
                45: spi_image_byte = 8'h83;
                46: spi_image_byte = 8'h23;
                47: spi_image_byte = 8'h65;
                48: spi_image_byte = 8'h63;
                49: spi_image_byte = 8'h1C;
                50: spi_image_byte = 8'h73;
                51: spi_image_byte = 8'h02;
                52: spi_image_byte = 8'h03;
                53: spi_image_byte = 8'hA3;
                54: spi_image_byte = 8'hC2;
                55: spi_image_byte = 8'h00;
                56: spi_image_byte = 8'hB7;
                57: spi_image_byte = 8'h03;
                58: spi_image_byte = 8'h00;
                59: spi_image_byte = 8'h10;
                60: spi_image_byte = 8'h93;
                61: spi_image_byte = 8'h83;
                62: spi_image_byte = 8'h03;
                63: spi_image_byte = 8'h02;
                64: spi_image_byte = 8'h63;
                65: spi_image_byte = 8'h14;
                66: spi_image_byte = 8'h73;
                67: spi_image_byte = 8'h02;
                68: spi_image_byte = 8'hB7;
                69: spi_image_byte = 8'h12;
                70: spi_image_byte = 8'h00;
                71: spi_image_byte = 8'h20;
                72: spi_image_byte = 8'h13;
                73: spi_image_byte = 8'h03;
                74: spi_image_byte = 8'hA0;
                75: spi_image_byte = 8'h00;
                76: spi_image_byte = 8'h23;
                77: spi_image_byte = 8'hA0;
                78: spi_image_byte = 8'h62;
                79: spi_image_byte = 8'h00;
                80: spi_image_byte = 8'hB7;
                81: spi_image_byte = 8'h02;
                82: spi_image_byte = 8'h00;
                83: spi_image_byte = 8'h20;
                84: spi_image_byte = 8'h13;
                85: spi_image_byte = 8'h03;
                86: spi_image_byte = 8'h90;
                87: spi_image_byte = 8'h04;
                88: spi_image_byte = 8'h23;
                89: spi_image_byte = 8'hA2;
                90: spi_image_byte = 8'h62;
                91: spi_image_byte = 8'h00;
                92: spi_image_byte = 8'h13;
                93: spi_image_byte = 8'h03;
                94: spi_image_byte = 8'h70;
                95: spi_image_byte = 8'h04;
                96: spi_image_byte = 8'h23;
                97: spi_image_byte = 8'hA2;
                98: spi_image_byte = 8'h62;
                99: spi_image_byte = 8'h00;
                100: spi_image_byte = 8'h6F;
                101: spi_image_byte = 8'h00;
                102: spi_image_byte = 8'h00;
                103: spi_image_byte = 8'h01;
                104: spi_image_byte = 8'hB7;
                105: spi_image_byte = 8'h02;
                106: spi_image_byte = 8'h00;
                107: spi_image_byte = 8'h20;
                108: spi_image_byte = 8'h13;
                109: spi_image_byte = 8'h03;
                110: spi_image_byte = 8'h50;
                111: spi_image_byte = 8'h04;
                112: spi_image_byte = 8'h23;
                113: spi_image_byte = 8'hA2;
                114: spi_image_byte = 8'h62;
                115: spi_image_byte = 8'h00;
                116: spi_image_byte = 8'h6F;
                117: spi_image_byte = 8'h00;
                118: spi_image_byte = 8'h00;
                119: spi_image_byte = 8'h00;
                default: spi_image_byte = 8'hFF;
            endcase
        end
    endfunction

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
        uart_mon_read = 1'b0;
        uart_mon_valid_prev = 1'b0;
        uart_last_byte = 8'h00;
        uart_shift4 = 32'h00000000;
        uart_shift5 = 40'h0000000000;
        uart_shift6 = 48'h000000000000;
        uart_shift7 = 56'h00000000000000;
        uart_shift8 = 64'h0000000000000000;
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
        app_info_seen = 1'b0;
        app_go_seen = 1'b0;
        go_command_sent = 1'b0;
        panel_bg_seen = 1'b0;
        panel_label_seen = 1'b0;
        panel_led_zero_seen = 1'b0;
        panel_led_a_seen = 1'b0;
        panel_status_ok_seen = 1'b0;

        $display("Starting top_basys3 smoke simulation...");

        repeat (20) @(posedge clk);
        btnC = 1'b0;

        wait_for_prompt(2, 1500000);
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
        wait_for_prompt(5, 600000);
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
        wait_for_prompt(12, 400000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h6E);
        wait_for_prompt(13, 400000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h70);
        wait_for_prompt(14, 400000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        go_command_sent = 1'b1;
        uart_send_byte(8'h67);
        // Wait long enough for the VGA scan to wrap and redraw the top-left
        // status panel after the SRAM app updates LED=0xA.
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

        if (dut.soc_i.npu_i.result_reg !== NPU_DEMO_EXPECT) begin
            $display("FAIL: MMIO NPU result register is 0x%08x instead of 0x%08x.",
                     dut.soc_i.npu_i.result_reg, NPU_DEMO_EXPECT);
            $finish;
        end

        if (led[0] !== 1'b0) begin
            $display("FAIL: LED0 did not toggle low after 'l' command.");
            $finish;
        end

        if (dut.soc_i.sram_i.mem[0] !== BOOT_INFO_MAGIC ||
            dut.soc_i.sram_i.mem[1] !== 32'h10000020 ||
            dut.soc_i.sram_i.mem[2] !== 32'h00000058 ||
            dut.soc_i.sram_i.mem[3] !== 32'h10000020 ||
            dut.soc_i.sram_i.mem[4] !== 32'h468F83F2 ||
            dut.soc_i.sram_i.mem[5] !== 32'h00000001) begin
            $display("FAIL: Boot info block was not written as expected.");
            $display("      info[0]=0x%08x info[1]=0x%08x info[2]=0x%08x info[3]=0x%08x",
                     dut.soc_i.sram_i.mem[0], dut.soc_i.sram_i.mem[1],
                     dut.soc_i.sram_i.mem[2], dut.soc_i.sram_i.mem[3]);
            $display("      info[4]=0x%08x info[5]=0x%08x",
                     dut.soc_i.sram_i.mem[4], dut.soc_i.sram_i.mem[5]);
            $finish;
        end

        if (dut.soc_i.sram_i.mem[8] !== 32'h100002B7 ||
            dut.soc_i.sram_i.mem[9] !== 32'h0002A303 ||
            dut.soc_i.sram_i.mem[10] !== 32'h494253B7 ||
            dut.soc_i.sram_i.mem[11] !== 32'h65238393 ||
            dut.soc_i.sram_i.mem[12] !== 32'h02731C63 ||
            dut.soc_i.sram_i.mem[13] !== 32'h00C2A303 ||
            dut.soc_i.sram_i.mem[14] !== 32'h100003B7 ||
            dut.soc_i.sram_i.mem[15] !== 32'h02038393 ||
            dut.soc_i.sram_i.mem[16] !== 32'h02731463 ||
            dut.soc_i.sram_i.mem[17] !== 32'h200012B7 ||
            dut.soc_i.sram_i.mem[18] !== 32'h00A00313 ||
            dut.soc_i.sram_i.mem[19] !== 32'h0062A023 ||
            dut.soc_i.sram_i.mem[20] !== 32'h200002B7 ||
            dut.soc_i.sram_i.mem[21] !== 32'h04900313 ||
            dut.soc_i.sram_i.mem[22] !== 32'h0062A223 ||
            dut.soc_i.sram_i.mem[23] !== 32'h04700313 ||
            dut.soc_i.sram_i.mem[24] !== 32'h0062A223 ||
            dut.soc_i.sram_i.mem[25] !== 32'h0100006F ||
            dut.soc_i.sram_i.mem[26] !== 32'h200002B7 ||
            dut.soc_i.sram_i.mem[27] !== 32'h04500313 ||
            dut.soc_i.sram_i.mem[28] !== 32'h0062A223 ||
            dut.soc_i.sram_i.mem[29] !== 32'h0000006F) begin
            $display("FAIL: SRAM payload words were not loaded as expected.");
            $display("      mem[8]=0x%08x mem[9]=0x%08x mem[10]=0x%08x mem[11]=0x%08x",
                     dut.soc_i.sram_i.mem[8], dut.soc_i.sram_i.mem[9],
                     dut.soc_i.sram_i.mem[10], dut.soc_i.sram_i.mem[11]);
            $display("      mem[12]=0x%08x mem[13]=0x%08x mem[14]=0x%08x mem[15]=0x%08x",
                     dut.soc_i.sram_i.mem[12], dut.soc_i.sram_i.mem[13],
                     dut.soc_i.sram_i.mem[14], dut.soc_i.sram_i.mem[15]);
            $display("      mem[16]=0x%08x mem[17]=0x%08x mem[18]=0x%08x mem[19]=0x%08x",
                     dut.soc_i.sram_i.mem[16], dut.soc_i.sram_i.mem[17],
                     dut.soc_i.sram_i.mem[18], dut.soc_i.sram_i.mem[19]);
            $display("      mem[20]=0x%08x mem[21]=0x%08x mem[22]=0x%08x mem[23]=0x%08x",
                     dut.soc_i.sram_i.mem[20], dut.soc_i.sram_i.mem[21],
                     dut.soc_i.sram_i.mem[22], dut.soc_i.sram_i.mem[23]);
            $display("      mem[24]=0x%08x mem[25]=0x%08x mem[26]=0x%08x mem[27]=0x%08x",
                     dut.soc_i.sram_i.mem[24], dut.soc_i.sram_i.mem[25],
                     dut.soc_i.sram_i.mem[26], dut.soc_i.sram_i.mem[27]);
            $display("      mem[28]=0x%08x mem[29]=0x%08x",
                     dut.soc_i.sram_i.mem[28], dut.soc_i.sram_i.mem[29]);
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

        if (led[3:0] !== 4'hA) begin
            $display("FAIL: SRAM app did not drive LED pattern 0xA after 'g'.");
            $finish;
        end

        if (spi_sclk_posedge_count < ((BOOT_HEADER_BYTES + BOOT_PAYLOAD_BYTES) * 8)) begin
            $display("FAIL: SPI SCLK toggled only %0d times; expected at least %0d for header + payload read.",
                     spi_sclk_posedge_count, (BOOT_HEADER_BYTES + BOOT_PAYLOAD_BYTES) * 8);
            $finish;
        end

        if (hsync_toggle_count == 0) begin
            $display("FAIL: VGA HSYNC never toggled.");
            $finish;
        end

        if (!panel_bg_seen) begin
            $display("FAIL: VGA status panel background was not observed.");
            $finish;
        end

        if (!panel_label_seen) begin
            $display("FAIL: VGA status panel text pixel was not observed.");
            $finish;
        end

        if (!panel_led_zero_seen) begin
            $display("FAIL: VGA status panel did not show LED value 0 after 'l'.");
            $finish;
        end

        if (!panel_led_a_seen) begin
            $display("FAIL: VGA status panel did not update LED value to A after 'g'.");
            $finish;
        end

        if (!panel_status_ok_seen) begin
            $display("FAIL: VGA status panel did not show boot status 0x00000001.");
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
            spi_shift_reg <= spi_image_byte(spi_byte_index);
            sd_miso <= (spi_image_byte(spi_byte_index) >= 8'h80);
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

            if (go_command_sent && uart_mon.recv_buf_data == 8'h49) begin
                app_info_seen <= 1'b1;
                $display("INFO: Observed SRAM app boot-info marker 'I' at time %0t.", $time);
            end

            if (go_command_sent && uart_mon.recv_buf_data == 8'h47) begin
                app_go_seen <= 1'b1;
                $display("INFO: Observed SRAM app UART marker 'G' at time %0t.", $time);
            end

            $display("INFO: UART monitor received byte 0x%02x at time %0t.", uart_mon.recv_buf_data, $time);
        end

        if (dut.vga_i.active && (dut.vga_i.x == PANEL_BG_X) && (dut.vga_i.y == PANEL_BG_Y) &&
            (vgaRed == 4'h0) && (vgaGreen == 4'h1) && (vgaBlue == 4'h4)) begin
            panel_bg_seen <= 1'b1;
        end

        if (dut.vga_i.active && (dut.vga_i.x == PANEL_LABEL_X) && (dut.vga_i.y == PANEL_LABEL_Y) &&
            (vgaRed == 4'hF) && (vgaGreen == 4'hF) && (vgaBlue == 4'hF)) begin
            panel_label_seen <= 1'b1;
        end

        if (dut.vga_i.active && (dut.vga_i.x == PANEL_LED_DIGIT_X) && (dut.vga_i.y == PANEL_LED_DIGIT_Y)) begin
            if (led_zero_msg_seen && (led[3:0] == 4'h0) &&
                (vgaRed == 4'h0) && (vgaGreen == 4'h1) && (vgaBlue == 4'h4)) begin
                panel_led_zero_seen <= 1'b1;
            end

            if ((led[3:0] == 4'hA) &&
                (vgaRed == 4'hF) && (vgaGreen == 4'hF) && (vgaBlue == 4'hF)) begin
                panel_led_a_seen <= 1'b1;
            end
        end

        if (dut.vga_i.active && (dut.vga_i.x == PANEL_STATUS_OK_X) && (dut.vga_i.y == PANEL_STATUS_OK_Y) &&
            (dut.debug_boot_status == 32'h00000001) &&
            (vgaRed == 4'hF) && (vgaGreen == 4'hF) && (vgaBlue == 4'hF)) begin
            panel_status_ok_seen <= 1'b1;
        end
    end
endmodule
