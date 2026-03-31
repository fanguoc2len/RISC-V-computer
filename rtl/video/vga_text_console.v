module vga_text_console (
    input  wire        clk_sys,
    input  wire        clk_pix,
    input  wire        resetn,
    input  wire [7:0]  accent,
    input  wire [15:0] led_value,
    input  wire [31:0] timer_lo,
    input  wire [31:0] boot_status,
    input  wire [7:0]  ps2_data,
    input  wire        ps2_valid,
    input  wire        text_char_valid,
    input  wire [7:0]  text_char,
    output wire        hsync,
    output wire        vsync,
    output reg  [3:0]  red,
    output reg  [3:0]  green,
    output reg  [3:0]  blue
);
    localparam integer TEXT_COLS = 80;
    localparam integer TEXT_ROWS = 29;
    localparam integer STATUS_ROW = 29;
    localparam integer TEXT_DEPTH = TEXT_COLS * TEXT_ROWS;

    wire [9:0] x;
    wire [9:0] y;
    wire active;

    reg [7:0] text_ram [0:TEXT_DEPTH-1];
    reg [6:0] cursor_col;
    reg [4:0] cursor_row;

    reg [7:0] current_char;
    reg [7:0] canon_char;
    reg [4:0] glyph_bits;
    reg text_pixel;
    reg cursor_pixel;
    reg status_row_active;
    integer cell_index;

    vga_timing_640x480 timing_i (
        .clk_pix (clk_pix),
        .resetn  (resetn),
        .x       (x),
        .y       (y),
        .hsync   (hsync),
        .vsync   (vsync),
        .active  (active)
    );

    task automatic clear_text_ram;
        integer idx;
        begin
            for (idx = 0; idx < TEXT_DEPTH; idx = idx + 1) begin
                text_ram[idx] = 8'h20;
            end
        end
    endtask

    task automatic scroll_text_ram;
        integer idx;
        begin
            for (idx = 0; idx < TEXT_COLS * (TEXT_ROWS - 1); idx = idx + 1) begin
                text_ram[idx] = text_ram[idx + TEXT_COLS];
            end

            for (idx = TEXT_COLS * (TEXT_ROWS - 1); idx < TEXT_DEPTH; idx = idx + 1) begin
                text_ram[idx] = 8'h20;
            end
        end
    endtask

    function [7:0] hex_ascii;
        input [3:0] nibble;
        begin
            case (nibble)
                4'h0: hex_ascii = 8'h30;
                4'h1: hex_ascii = 8'h31;
                4'h2: hex_ascii = 8'h32;
                4'h3: hex_ascii = 8'h33;
                4'h4: hex_ascii = 8'h34;
                4'h5: hex_ascii = 8'h35;
                4'h6: hex_ascii = 8'h36;
                4'h7: hex_ascii = 8'h37;
                4'h8: hex_ascii = 8'h38;
                4'h9: hex_ascii = 8'h39;
                4'hA: hex_ascii = 8'h41;
                4'hB: hex_ascii = 8'h42;
                4'hC: hex_ascii = 8'h43;
                4'hD: hex_ascii = 8'h44;
                4'hE: hex_ascii = 8'h45;
                default: hex_ascii = 8'h46;
            endcase
        end
    endfunction

    function [7:0] status_char;
        input integer idx;
        begin
            status_char = 8'h20;

            case (idx)
                0: status_char = 8'h4C; // L
                1: status_char = 8'h45; // E
                2: status_char = 8'h44; // D
                3: status_char = 8'h20;
                4: status_char = hex_ascii(led_value[15:12]);
                5: status_char = hex_ascii(led_value[11:8]);
                6: status_char = hex_ascii(led_value[7:4]);
                7: status_char = hex_ascii(led_value[3:0]);
                8: status_char = 8'h20;
                9: status_char = 8'h54; // T
                10: status_char = 8'h49; // I
                11: status_char = 8'h4D; // M
                12: status_char = 8'h45; // E
                13: status_char = 8'h20;
                14: status_char = hex_ascii(timer_lo[31:28]);
                15: status_char = hex_ascii(timer_lo[27:24]);
                16: status_char = hex_ascii(timer_lo[23:20]);
                17: status_char = hex_ascii(timer_lo[19:16]);
                18: status_char = hex_ascii(timer_lo[15:12]);
                19: status_char = hex_ascii(timer_lo[11:8]);
                20: status_char = hex_ascii(timer_lo[7:4]);
                21: status_char = hex_ascii(timer_lo[3:0]);
                22: status_char = 8'h20;
                23: status_char = 8'h50; // P
                24: status_char = 8'h53; // S
                25: status_char = 8'h32; // 2
                26: status_char = 8'h20;
                27: status_char = hex_ascii(ps2_data[7:4]);
                28: status_char = hex_ascii(ps2_data[3:0]);
                29: status_char = 8'h20;
                30: status_char = ps2_valid ? 8'h31 : 8'h30;
                31: status_char = 8'h20;
                32: status_char = 8'h53; // S
                33: status_char = 8'h54; // T
                34: status_char = 8'h41; // A
                35: status_char = 8'h54; // T
                36: status_char = 8'h20;
                37: status_char = hex_ascii(boot_status[31:28]);
                38: status_char = hex_ascii(boot_status[27:24]);
                39: status_char = hex_ascii(boot_status[23:20]);
                40: status_char = hex_ascii(boot_status[19:16]);
                41: status_char = hex_ascii(boot_status[15:12]);
                42: status_char = hex_ascii(boot_status[11:8]);
                43: status_char = hex_ascii(boot_status[7:4]);
                44: status_char = hex_ascii(boot_status[3:0]);
                default: status_char = 8'h20;
            endcase
        end
    endfunction

    function [4:0] font_row;
        input [7:0] ch;
        input integer row;
        begin
            font_row = 5'b00000;
            case (ch)
                8'h30: begin
                    case (row)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10011;
                        3: font_row = 5'b10101;
                        4: font_row = 5'b11001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b01110;
                    endcase
                end
                8'h31: begin
                    case (row)
                        0: font_row = 5'b00100;
                        1: font_row = 5'b01100;
                        2: font_row = 5'b00100;
                        3: font_row = 5'b00100;
                        4: font_row = 5'b00100;
                        5: font_row = 5'b00100;
                        default: font_row = 5'b01110;
                    endcase
                end
                8'h32: begin
                    case (row)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b00001;
                        3: font_row = 5'b00010;
                        4: font_row = 5'b00100;
                        5: font_row = 5'b01000;
                        default: font_row = 5'b11111;
                    endcase
                end
                8'h33: begin
                    case (row)
                        0: font_row = 5'b11110;
                        1: font_row = 5'b00001;
                        2: font_row = 5'b00001;
                        3: font_row = 5'b01110;
                        4: font_row = 5'b00001;
                        5: font_row = 5'b00001;
                        default: font_row = 5'b11110;
                    endcase
                end
                8'h34: begin
                    case (row)
                        0: font_row = 5'b00010;
                        1: font_row = 5'b00110;
                        2: font_row = 5'b01010;
                        3: font_row = 5'b10010;
                        4: font_row = 5'b11111;
                        5: font_row = 5'b00010;
                        default: font_row = 5'b00010;
                    endcase
                end
                8'h35: begin
                    case (row)
                        0: font_row = 5'b11111;
                        1: font_row = 5'b10000;
                        2: font_row = 5'b11110;
                        3: font_row = 5'b00001;
                        4: font_row = 5'b00001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b01110;
                    endcase
                end
                8'h36: begin
                    case (row)
                        0: font_row = 5'b00110;
                        1: font_row = 5'b01000;
                        2: font_row = 5'b10000;
                        3: font_row = 5'b11110;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b01110;
                    endcase
                end
                8'h37: begin
                    case (row)
                        0: font_row = 5'b11111;
                        1: font_row = 5'b00001;
                        2: font_row = 5'b00010;
                        3: font_row = 5'b00100;
                        4: font_row = 5'b01000;
                        5: font_row = 5'b01000;
                        default: font_row = 5'b01000;
                    endcase
                end
                8'h38: begin
                    case (row)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b01110;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b01110;
                    endcase
                end
                8'h39: begin
                    case (row)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b01111;
                        4: font_row = 5'b00001;
                        5: font_row = 5'b00010;
                        default: font_row = 5'b11100;
                    endcase
                end
                8'h41: begin
                    case (row)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b11111;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b10001;
                    endcase
                end
                8'h42: begin
                    case (row)
                        0: font_row = 5'b11110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b11110;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b11110;
                    endcase
                end
                8'h43: begin
                    case (row)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10000;
                        3: font_row = 5'b10000;
                        4: font_row = 5'b10000;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b01110;
                    endcase
                end
                8'h44: begin
                    case (row)
                        0: font_row = 5'b11110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b10001;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b11110;
                    endcase
                end
                8'h45: begin
                    case (row)
                        0: font_row = 5'b11111;
                        1: font_row = 5'b10000;
                        2: font_row = 5'b10000;
                        3: font_row = 5'b11110;
                        4: font_row = 5'b10000;
                        5: font_row = 5'b10000;
                        default: font_row = 5'b11111;
                    endcase
                end
                8'h46: begin
                    case (row)
                        0: font_row = 5'b11111;
                        1: font_row = 5'b10000;
                        2: font_row = 5'b10000;
                        3: font_row = 5'b11110;
                        4: font_row = 5'b10000;
                        5: font_row = 5'b10000;
                        default: font_row = 5'b10000;
                    endcase
                end
                8'h47: begin
                    case (row)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10000;
                        3: font_row = 5'b10111;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b01110;
                    endcase
                end
                8'h48: begin
                    case (row)
                        0: font_row = 5'b10001;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b11111;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b10001;
                    endcase
                end
                8'h49: begin
                    case (row)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b00100;
                        2: font_row = 5'b00100;
                        3: font_row = 5'b00100;
                        4: font_row = 5'b00100;
                        5: font_row = 5'b00100;
                        default: font_row = 5'b01110;
                    endcase
                end
                8'h4A: begin
                    case (row)
                        0: font_row = 5'b00001;
                        1: font_row = 5'b00001;
                        2: font_row = 5'b00001;
                        3: font_row = 5'b00001;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b01110;
                    endcase
                end
                8'h4B: begin
                    case (row)
                        0: font_row = 5'b10001;
                        1: font_row = 5'b10010;
                        2: font_row = 5'b10100;
                        3: font_row = 5'b11000;
                        4: font_row = 5'b10100;
                        5: font_row = 5'b10010;
                        default: font_row = 5'b10001;
                    endcase
                end
                8'h4C: begin
                    case (row)
                        0: font_row = 5'b10000;
                        1: font_row = 5'b10000;
                        2: font_row = 5'b10000;
                        3: font_row = 5'b10000;
                        4: font_row = 5'b10000;
                        5: font_row = 5'b10000;
                        default: font_row = 5'b11111;
                    endcase
                end
                8'h4D: begin
                    case (row)
                        0: font_row = 5'b10001;
                        1: font_row = 5'b11011;
                        2: font_row = 5'b10101;
                        3: font_row = 5'b10101;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b10001;
                    endcase
                end
                8'h4E: begin
                    case (row)
                        0: font_row = 5'b10001;
                        1: font_row = 5'b11001;
                        2: font_row = 5'b10101;
                        3: font_row = 5'b10011;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b10001;
                    endcase
                end
                8'h4F: begin
                    case (row)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b10001;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b01110;
                    endcase
                end
                8'h50: begin
                    case (row)
                        0: font_row = 5'b11110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b11110;
                        4: font_row = 5'b10000;
                        5: font_row = 5'b10000;
                        default: font_row = 5'b10000;
                    endcase
                end
                8'h51: begin
                    case (row)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b10001;
                        4: font_row = 5'b10101;
                        5: font_row = 5'b10010;
                        default: font_row = 5'b01101;
                    endcase
                end
                8'h52: begin
                    case (row)
                        0: font_row = 5'b11110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b11110;
                        4: font_row = 5'b10100;
                        5: font_row = 5'b10010;
                        default: font_row = 5'b10001;
                    endcase
                end
                8'h53: begin
                    case (row)
                        0: font_row = 5'b01111;
                        1: font_row = 5'b10000;
                        2: font_row = 5'b10000;
                        3: font_row = 5'b01110;
                        4: font_row = 5'b00001;
                        5: font_row = 5'b00001;
                        default: font_row = 5'b11110;
                    endcase
                end
                8'h54: begin
                    case (row)
                        0: font_row = 5'b11111;
                        1: font_row = 5'b00100;
                        2: font_row = 5'b00100;
                        3: font_row = 5'b00100;
                        4: font_row = 5'b00100;
                        5: font_row = 5'b00100;
                        default: font_row = 5'b00100;
                    endcase
                end
                8'h55: begin
                    case (row)
                        0: font_row = 5'b10001;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b10001;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b01110;
                    endcase
                end
                8'h56: begin
                    case (row)
                        0: font_row = 5'b10001;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b10001;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b01010;
                        default: font_row = 5'b00100;
                    endcase
                end
                8'h57: begin
                    case (row)
                        0: font_row = 5'b10001;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b10101;
                        4: font_row = 5'b10101;
                        5: font_row = 5'b10101;
                        default: font_row = 5'b01010;
                    endcase
                end
                8'h58: begin
                    case (row)
                        0: font_row = 5'b10001;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b01010;
                        3: font_row = 5'b00100;
                        4: font_row = 5'b01010;
                        5: font_row = 5'b10001;
                        default: font_row = 5'b10001;
                    endcase
                end
                8'h59: begin
                    case (row)
                        0: font_row = 5'b10001;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b01010;
                        3: font_row = 5'b00100;
                        4: font_row = 5'b00100;
                        5: font_row = 5'b00100;
                        default: font_row = 5'b00100;
                    endcase
                end
                8'h5A: begin
                    case (row)
                        0: font_row = 5'b11111;
                        1: font_row = 5'b00001;
                        2: font_row = 5'b00010;
                        3: font_row = 5'b00100;
                        4: font_row = 5'b01000;
                        5: font_row = 5'b10000;
                        default: font_row = 5'b11111;
                    endcase
                end
                8'h2D: begin
                    case (row)
                        3: font_row = 5'b11111;
                        default: font_row = 5'b00000;
                    endcase
                end
                8'h2E: begin
                    case (row)
                        5: font_row = 5'b00100;
                        6: font_row = 5'b00100;
                        default: font_row = 5'b00000;
                    endcase
                end
                8'h3A: begin
                    case (row)
                        1: font_row = 5'b00100;
                        2: font_row = 5'b00100;
                        4: font_row = 5'b00100;
                        5: font_row = 5'b00100;
                        default: font_row = 5'b00000;
                    endcase
                end
                8'h3D: begin
                    case (row)
                        2: font_row = 5'b11111;
                        4: font_row = 5'b11111;
                        default: font_row = 5'b00000;
                    endcase
                end
                8'h3F: begin
                    case (row)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b00010;
                        3: font_row = 5'b00100;
                        4: font_row = 5'b00100;
                        5: font_row = 5'b00000;
                        default: font_row = 5'b00100;
                    endcase
                end
                8'h3E: begin
                    case (row)
                        1: font_row = 5'b10000;
                        2: font_row = 5'b01000;
                        3: font_row = 5'b00100;
                        4: font_row = 5'b01000;
                        5: font_row = 5'b10000;
                        default: font_row = 5'b00000;
                    endcase
                end
                8'h5F: begin
                    case (row)
                        6: font_row = 5'b11111;
                        default: font_row = 5'b00000;
                    endcase
                end
                default: font_row = 5'b00000;
            endcase
        end
    endfunction

    always @(posedge clk_sys or negedge resetn) begin
        if (!resetn) begin
            clear_text_ram();
            cursor_col = 7'd0;
            cursor_row = 5'd0;
        end else if (text_char_valid) begin
            case (text_char)
                8'h0C: begin
                    clear_text_ram();
                    cursor_col = 7'd0;
                    cursor_row = 5'd0;
                end
                8'h0D: begin
                    cursor_col = 7'd0;
                end
                8'h0A: begin
                    cursor_col = 7'd0;
                    if (cursor_row == TEXT_ROWS - 1) begin
                        scroll_text_ram();
                    end else begin
                        cursor_row = cursor_row + 5'd1;
                    end
                end
                8'h08: begin
                    if (cursor_col != 0) begin
                        text_ram[(cursor_row * TEXT_COLS) + cursor_col - 1] = 8'h20;
                        cursor_col = cursor_col - 7'd1;
                    end
                end
                default: begin
                    if ((text_char >= 8'h20) && (text_char <= 8'h7E)) begin
                        text_ram[(cursor_row * TEXT_COLS) + cursor_col] = text_char;
                        if (cursor_col == TEXT_COLS - 1) begin
                            cursor_col = 7'd0;
                            if (cursor_row == TEXT_ROWS - 1) begin
                                scroll_text_ram();
                            end else begin
                                cursor_row = cursor_row + 5'd1;
                            end
                        end else begin
                            cursor_col = cursor_col + 7'd1;
                        end
                    end
                end
            endcase
        end
    end

    always @(*) begin
        current_char = 8'h20;
        canon_char = 8'h20;
        glyph_bits = 5'b00000;
        text_pixel = 1'b0;
        cursor_pixel = 1'b0;
        status_row_active = 1'b0;
        cell_index = 0;

        red = 4'h0;
        green = 4'h0;
        blue = 4'h1;

        if (active) begin
            status_row_active = (y[8:4] == 5'd29);

            if (status_row_active) begin
                current_char = status_char(x[9:3]);
            end else if (y[8:4] < TEXT_ROWS) begin
                cell_index = (y[8:4] * TEXT_COLS) + x[9:3];
                current_char = text_ram[cell_index];
            end

            canon_char = ((current_char >= 8'h61) && (current_char <= 8'h7A)) ? (current_char - 8'h20) : current_char;

            if ((x[2:0] >= 3'd1) && (x[2:0] <= 3'd5) &&
                (y[3:0] >= 4'd1) && (y[3:0] <= 4'd14)) begin
                glyph_bits = font_row(canon_char, (y[3:0] - 4'd1) >> 1);
                text_pixel = glyph_bits[5 - x[2:0]];
            end

            if (!status_row_active &&
                (y[8:4] == cursor_row) &&
                (x[9:3] == cursor_col) &&
                (y[3:0] >= 4'd13)) begin
                cursor_pixel = 1'b1;
            end

            if (status_row_active) begin
                if (text_pixel) begin
                    red = 4'hF;
                    green = 4'hF;
                    blue = 4'hF;
                end else begin
                    red = 4'h1;
                    green = accent[3:0];
                    blue = accent[7:4];
                end
            end else if (text_pixel) begin
                red = 4'hF;
                green = 4'hC;
                blue = 4'h4;
            end else if (cursor_pixel) begin
                red = accent[3:0];
                green = 4'hF;
                blue = accent[7:4];
            end else begin
                red = 4'h0;
                green = 4'h1;
                blue = 4'h2;
            end
        end else begin
            red = 4'h0;
            green = 4'h0;
            blue = 4'h0;
        end
    end
endmodule
