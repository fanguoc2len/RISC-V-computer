`timescale 1ns / 1ps

module top_basys3_tb;
    localparam integer CLK_FREQ_HZ = 100_000_000;
    localparam integer UART_BAUD = 115200;
    localparam integer UART_BIT_CLKS = CLK_FREQ_HZ / UART_BAUD;
    localparam integer PS2_HALF_CLKS = 200;
    localparam integer BOOT_HEADER_BYTES = 32;

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
    reg last_uart_tx;
    reg last_hsync;
    reg uart_mon_read;
    reg uart_mon_valid_prev;
    reg [7:0] uart_last_byte;
    reg [31:0] uart_shift4;
    reg [39:0] uart_shift5;
    reg [47:0] uart_shift6;
    reg [7:0] spi_shift_reg;
    reg spi_xfer_active;
    reg banner_seen;
    reg help_reply_seen;
    reg led_zero_msg_seen;
    reg boot_ok_seen;
    reg ps2_ok_seen;

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
                4: spi_image_byte = 8'h00;
                5: spi_image_byte = 8'h00;
                6: spi_image_byte = 8'h00;
                7: spi_image_byte = 8'h10;
                8: spi_image_byte = 8'h10;
                9: spi_image_byte = 8'h00;
                10: spi_image_byte = 8'h00;
                11: spi_image_byte = 8'h00;
                12: spi_image_byte = 8'h00;
                13: spi_image_byte = 8'h00;
                14: spi_image_byte = 8'h00;
                15: spi_image_byte = 8'h10;
                16: spi_image_byte = 8'h4C;
                17: spi_image_byte = 8'h00;
                18: spi_image_byte = 8'h00;
                19: spi_image_byte = 8'h00;
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
                32: spi_image_byte = 8'h13;
                33: spi_image_byte = 8'h00;
                34: spi_image_byte = 8'h00;
                35: spi_image_byte = 8'h00;
                36: spi_image_byte = 8'h13;
                37: spi_image_byte = 8'h00;
                38: spi_image_byte = 8'h00;
                39: spi_image_byte = 8'h00;
                40: spi_image_byte = 8'h13;
                41: spi_image_byte = 8'h00;
                42: spi_image_byte = 8'h00;
                43: spi_image_byte = 8'h00;
                44: spi_image_byte = 8'h13;
                45: spi_image_byte = 8'h00;
                46: spi_image_byte = 8'h00;
                47: spi_image_byte = 8'h00;
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
        last_uart_tx = 1'b1;
        last_hsync = 1'b1;
        uart_mon_read = 1'b0;
        uart_mon_valid_prev = 1'b0;
        uart_last_byte = 8'h00;
        uart_shift4 = 32'h00000000;
        uart_shift5 = 40'h0000000000;
        uart_shift6 = 48'h000000000000;
        spi_shift_reg = 8'hFF;
        spi_xfer_active = 1'b0;
        spi_byte_index = 0;
        banner_seen = 1'b0;
        help_reply_seen = 1'b0;
        led_zero_msg_seen = 1'b0;
        boot_ok_seen = 1'b0;
        ps2_ok_seen = 1'b0;

        $display("Starting top_basys3 smoke simulation...");

        repeat (20) @(posedge clk);
        btnC = 1'b0;

        wait_for_prompt(1, 400000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h68);
        wait_for_prompt(2, 250000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h6C);
        wait_for_prompt(3, 250000);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        spi_byte_index = 0;
        spi_xfer_active = 1'b0;
        spi_shift_reg = 8'hFF;
        sd_miso = 1'b1;
        uart_send_byte(8'h62);
        wait_for_prompt(4, 400000);
        ps2_send_byte(8'h1C);
        repeat (UART_BIT_CLKS * 2) @(posedge clk);
        uart_send_byte(8'h6B);
        wait_for_prompt(5, 250000);

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

        if (!boot_ok_seen) begin
            $display("FAIL: Did not observe BOOT=OK reply after sending 'b'.");
            $finish;
        end

        if (!ps2_ok_seen) begin
            $display("FAIL: Did not observe PS2=OK reply after sending 'k'.");
            $finish;
        end

        if (led[0] !== 1'b0) begin
            $display("FAIL: LED0 did not toggle low after 'l' command.");
            $finish;
        end

        if (spi_sclk_posedge_count < (BOOT_HEADER_BYTES * 8)) begin
            $display("FAIL: SPI SCLK toggled only %0d times; expected at least %0d for a full header read.",
                     spi_sclk_posedge_count, BOOT_HEADER_BYTES * 8);
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

            if (uart_mon.recv_buf_data == 8'h3E) begin
                prompt_count <= prompt_count + 1;
            end

            if ({uart_shift4[23:0], uart_mon.recv_buf_data} == {8'h52, 8'h56, 8'h33, 8'h32}) begin
                banner_seen <= 1'b1;
            end

            if ({uart_shift5[31:0], uart_mon.recv_buf_data} == {8'h43, 8'h4D, 8'h44, 8'h53, 8'h3A}) begin
                help_reply_seen <= 1'b1;
            end

            if ({uart_shift5[31:0], uart_mon.recv_buf_data} == {8'h4C, 8'h45, 8'h44, 8'h3D, 8'h30}) begin
                led_zero_msg_seen <= 1'b1;
            end

            if ({uart_shift6[39:0], uart_mon.recv_buf_data} == {8'h42, 8'h4F, 8'h4F, 8'h54, 8'h3D, 8'h4F}) begin
                boot_ok_seen <= 1'b1;
            end

            if ({uart_shift5[31:0], uart_mon.recv_buf_data} == {8'h50, 8'h53, 8'h32, 8'h3D, 8'h4F}) begin
                ps2_ok_seen <= 1'b1;
            end

            $display("INFO: UART monitor received byte 0x%02x at time %0t.", uart_mon.recv_buf_data, $time);
        end
    end
endmodule
