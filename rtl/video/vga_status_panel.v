module vga_status_panel (
    input  wire        clk_pix,
    input  wire        resetn,
    input  wire [7:0]  accent,
    input  wire [15:0] led_value,
    input  wire [31:0] timer_lo,
    input  wire [7:0]  ps2_data,
    input  wire        ps2_valid,
    output wire        hsync,
    output wire        vsync,
    output reg  [3:0]  red,
    output reg  [3:0]  green,
    output reg  [3:0]  blue
);
    localparam integer PANEL_X0 = 12;
    localparam integer PANEL_Y0 = 12;
    localparam integer PANEL_W = 176;
    localparam integer PANEL_H = 56;
    localparam integer TEXT_X0 = 16;
    localparam integer TEXT_Y0 = 16;
    localparam integer CHAR_SCALE = 2;
    localparam integer GLYPH_W = 4;
    localparam integer GLYPH_H = 5;
    localparam integer CHAR_CELL_W = 10;
    localparam integer CHAR_CELL_H = 10;
    localparam integer LINE_ADVANCE = 14;

    wire [9:0] x;
    wire [9:0] y;
    wire active;
    wire frame_border;

    reg panel_on;
    reg panel_border;
    reg text_on;
    reg [7:0] glyph_char;
    reg [3:0] glyph_bits;
    integer panel_local_x;
    integer panel_local_y;
    integer line_index;
    integer row_in_line;
    integer char_index;
    integer col_in_cell;
    integer glyph_row;
    integer glyph_col;

    vga_timing_640x480 timing_i (
        .clk_pix (clk_pix),
        .resetn  (resetn),
        .x       (x),
        .y       (y),
        .hsync   (hsync),
        .vsync   (vsync),
        .active  (active)
    );

    assign frame_border = (x < 10'd4) || (x >= 10'd636) || (y < 10'd4) || (y >= 10'd476);

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

    function [7:0] line_char;
        input [1:0] line_sel;
        input integer idx;
        begin
            line_char = 8'h20;

            case (line_sel)
                2'd0: begin
                    case (idx)
                        0: line_char = 8'h4C; // L
                        1: line_char = 8'h45; // E
                        2: line_char = 8'h44; // D
                        3: line_char = 8'h20;
                        4: line_char = hex_ascii(led_value[15:12]);
                        5: line_char = hex_ascii(led_value[11:8]);
                        6: line_char = hex_ascii(led_value[7:4]);
                        7: line_char = hex_ascii(led_value[3:0]);
                        default: line_char = 8'h20;
                    endcase
                end
                2'd1: begin
                    case (idx)
                        0: line_char = 8'h54; // T
                        1: line_char = 8'h49; // I
                        2: line_char = 8'h4D; // M
                        3: line_char = 8'h45; // E
                        4: line_char = 8'h20;
                        5: line_char = hex_ascii(timer_lo[31:28]);
                        6: line_char = hex_ascii(timer_lo[27:24]);
                        7: line_char = hex_ascii(timer_lo[23:20]);
                        8: line_char = hex_ascii(timer_lo[19:16]);
                        9: line_char = hex_ascii(timer_lo[15:12]);
                        10: line_char = hex_ascii(timer_lo[11:8]);
                        11: line_char = hex_ascii(timer_lo[7:4]);
                        12: line_char = hex_ascii(timer_lo[3:0]);
                        default: line_char = 8'h20;
                    endcase
                end
                default: begin
                    case (idx)
                        0: line_char = 8'h50; // P
                        1: line_char = 8'h53; // S
                        2: line_char = 8'h32; // 2
                        3: line_char = 8'h20;
                        4: line_char = hex_ascii(ps2_data[7:4]);
                        5: line_char = hex_ascii(ps2_data[3:0]);
                        6: line_char = 8'h20;
                        7: line_char = ps2_valid ? 8'h31 : 8'h30;
                        default: line_char = 8'h20;
                    endcase
                end
            endcase
        end
    endfunction

    function [3:0] font_row;
        input [7:0] ch;
        input integer row;
        begin
            font_row = 4'b0000;
            case (ch)
                8'h30: begin
                    case (row)
                        0: font_row = 4'b1111;
                        1: font_row = 4'b1001;
                        2: font_row = 4'b1001;
                        3: font_row = 4'b1001;
                        default: font_row = 4'b1111;
                    endcase
                end
                8'h31: begin
                    case (row)
                        0: font_row = 4'b0010;
                        1: font_row = 4'b0110;
                        2: font_row = 4'b0010;
                        3: font_row = 4'b0010;
                        default: font_row = 4'b0111;
                    endcase
                end
                8'h32: begin
                    case (row)
                        0: font_row = 4'b1110;
                        1: font_row = 4'b0001;
                        2: font_row = 4'b0110;
                        3: font_row = 4'b1000;
                        default: font_row = 4'b1111;
                    endcase
                end
                8'h33: begin
                    case (row)
                        0: font_row = 4'b1110;
                        1: font_row = 4'b0001;
                        2: font_row = 4'b0110;
                        3: font_row = 4'b0001;
                        default: font_row = 4'b1110;
                    endcase
                end
                8'h34: begin
                    case (row)
                        0: font_row = 4'b1001;
                        1: font_row = 4'b1001;
                        2: font_row = 4'b1111;
                        3: font_row = 4'b0001;
                        default: font_row = 4'b0001;
                    endcase
                end
                8'h35: begin
                    case (row)
                        0: font_row = 4'b1111;
                        1: font_row = 4'b1000;
                        2: font_row = 4'b1110;
                        3: font_row = 4'b0001;
                        default: font_row = 4'b1110;
                    endcase
                end
                8'h36: begin
                    case (row)
                        0: font_row = 4'b0111;
                        1: font_row = 4'b1000;
                        2: font_row = 4'b1110;
                        3: font_row = 4'b1001;
                        default: font_row = 4'b0110;
                    endcase
                end
                8'h37: begin
                    case (row)
                        0: font_row = 4'b1111;
                        1: font_row = 4'b0001;
                        2: font_row = 4'b0010;
                        3: font_row = 4'b0100;
                        default: font_row = 4'b0100;
                    endcase
                end
                8'h38: begin
                    case (row)
                        0: font_row = 4'b0110;
                        1: font_row = 4'b1001;
                        2: font_row = 4'b0110;
                        3: font_row = 4'b1001;
                        default: font_row = 4'b0110;
                    endcase
                end
                8'h39: begin
                    case (row)
                        0: font_row = 4'b0110;
                        1: font_row = 4'b1001;
                        2: font_row = 4'b0111;
                        3: font_row = 4'b0001;
                        default: font_row = 4'b1110;
                    endcase
                end
                8'h41: begin
                    case (row)
                        0: font_row = 4'b0110;
                        1: font_row = 4'b1001;
                        2: font_row = 4'b1111;
                        3: font_row = 4'b1001;
                        default: font_row = 4'b1001;
                    endcase
                end
                8'h42: begin
                    case (row)
                        0: font_row = 4'b1110;
                        1: font_row = 4'b1001;
                        2: font_row = 4'b1110;
                        3: font_row = 4'b1001;
                        default: font_row = 4'b1110;
                    endcase
                end
                8'h43: begin
                    case (row)
                        0: font_row = 4'b0111;
                        1: font_row = 4'b1000;
                        2: font_row = 4'b1000;
                        3: font_row = 4'b1000;
                        default: font_row = 4'b0111;
                    endcase
                end
                8'h44: begin
                    case (row)
                        0: font_row = 4'b1110;
                        1: font_row = 4'b1001;
                        2: font_row = 4'b1001;
                        3: font_row = 4'b1001;
                        default: font_row = 4'b1110;
                    endcase
                end
                8'h45: begin
                    case (row)
                        0: font_row = 4'b1111;
                        1: font_row = 4'b1000;
                        2: font_row = 4'b1110;
                        3: font_row = 4'b1000;
                        default: font_row = 4'b1111;
                    endcase
                end
                8'h46: begin
                    case (row)
                        0: font_row = 4'b1111;
                        1: font_row = 4'b1000;
                        2: font_row = 4'b1110;
                        3: font_row = 4'b1000;
                        default: font_row = 4'b1000;
                    endcase
                end
                8'h49: begin
                    case (row)
                        0: font_row = 4'b0111;
                        1: font_row = 4'b0010;
                        2: font_row = 4'b0010;
                        3: font_row = 4'b0010;
                        default: font_row = 4'b0111;
                    endcase
                end
                8'h4C: begin
                    case (row)
                        0: font_row = 4'b1000;
                        1: font_row = 4'b1000;
                        2: font_row = 4'b1000;
                        3: font_row = 4'b1000;
                        default: font_row = 4'b1111;
                    endcase
                end
                8'h4D: begin
                    case (row)
                        0: font_row = 4'b1001;
                        1: font_row = 4'b1111;
                        2: font_row = 4'b1111;
                        3: font_row = 4'b1001;
                        default: font_row = 4'b1001;
                    endcase
                end
                8'h50: begin
                    case (row)
                        0: font_row = 4'b1110;
                        1: font_row = 4'b1001;
                        2: font_row = 4'b1110;
                        3: font_row = 4'b1000;
                        default: font_row = 4'b1000;
                    endcase
                end
                8'h53: begin
                    case (row)
                        0: font_row = 4'b0111;
                        1: font_row = 4'b1000;
                        2: font_row = 4'b0110;
                        3: font_row = 4'b0001;
                        default: font_row = 4'b1110;
                    endcase
                end
                8'h54: begin
                    case (row)
                        0: font_row = 4'b1111;
                        1: font_row = 4'b0010;
                        2: font_row = 4'b0010;
                        3: font_row = 4'b0010;
                        default: font_row = 4'b0010;
                    endcase
                end
                default: font_row = 4'b0000;
            endcase
        end
    endfunction

    always @(*) begin
        panel_on = 1'b0;
        panel_border = 1'b0;
        text_on = 1'b0;
        glyph_char = 8'h20;
        glyph_bits = 4'b0000;
        panel_local_x = 0;
        panel_local_y = 0;
        line_index = 0;
        row_in_line = 0;
        char_index = 0;
        col_in_cell = 0;
        glyph_row = 0;
        glyph_col = 0;

        if (active && (x >= PANEL_X0) && (x < PANEL_X0 + PANEL_W) &&
            (y >= PANEL_Y0) && (y < PANEL_Y0 + PANEL_H)) begin
            panel_on = 1'b1;
            panel_local_x = x - PANEL_X0;
            panel_local_y = y - PANEL_Y0;
            panel_border = (panel_local_x < 3) || (panel_local_x >= PANEL_W - 3) ||
                           (panel_local_y < 3) || (panel_local_y >= PANEL_H - 3);

            if ((panel_local_x >= TEXT_X0) && (panel_local_y >= TEXT_Y0)) begin
                line_index = (panel_local_y - TEXT_Y0) / LINE_ADVANCE;
                row_in_line = (panel_local_y - TEXT_Y0) % LINE_ADVANCE;
                char_index = (panel_local_x - TEXT_X0) / CHAR_CELL_W;
                col_in_cell = (panel_local_x - TEXT_X0) % CHAR_CELL_W;

                if ((line_index >= 0) && (line_index < 3) &&
                    (row_in_line >= 0) && (row_in_line < CHAR_CELL_H) &&
                    (char_index >= 0) && (char_index < 13) &&
                    (col_in_cell >= 0) && (col_in_cell < (GLYPH_W * CHAR_SCALE))) begin
                    glyph_char = line_char(line_index[1:0], char_index);
                    glyph_row = row_in_line / CHAR_SCALE;
                    glyph_col = col_in_cell / CHAR_SCALE;
                    glyph_bits = font_row(glyph_char, glyph_row);
                    text_on = glyph_bits[GLYPH_W - 1 - glyph_col];
                end
            end
        end
    end

    always @(*) begin
        red = 4'h0;
        green = 4'h0;
        blue = 4'h0;

        if (active) begin
            if (frame_border) begin
                red = 4'hF;
                green = accent[3:0];
                blue = accent[7:4];
            end else begin
                case (x[9:7])
                    3'd0: begin red = 4'hF; green = 4'h0; blue = 4'h0; end
                    3'd1: begin red = 4'hF; green = 4'h8; blue = 4'h0; end
                    3'd2: begin red = 4'hF; green = 4'hF; blue = 4'h0; end
                    3'd3: begin red = 4'h0; green = 4'hF; blue = 4'h0; end
                    3'd4: begin red = 4'h0; green = 4'hF; blue = 4'hF; end
                    3'd5: begin red = 4'h0; green = 4'h0; blue = 4'hF; end
                    3'd6: begin red = 4'h8; green = 4'h0; blue = 4'hF; end
                    default: begin red = accent[3:0]; green = accent[7:4]; blue = 4'hF; end
                endcase
            end

            if (panel_on) begin
                if (panel_border) begin
                    red = 4'hF;
                    green = accent[3:0];
                    blue = accent[7:4];
                end else begin
                    red = 4'h0;
                    green = 4'h1;
                    blue = 4'h4;
                end

                if (text_on) begin
                    red = 4'hF;
                    green = 4'hF;
                    blue = 4'hF;
                end
            end
        end
    end
endmodule
