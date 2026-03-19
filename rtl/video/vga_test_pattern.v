module vga_test_pattern (
    input  wire       clk_pix,
    input  wire       resetn,
    input  wire [7:0] accent,
    output wire       hsync,
    output wire       vsync,
    output reg  [3:0] red,
    output reg  [3:0] green,
    output reg  [3:0] blue
);
    wire [9:0] x;
    wire [9:0] y;
    wire active;
    wire border;

    vga_timing_640x480 timing_i (
        .clk_pix (clk_pix),
        .resetn  (resetn),
        .x       (x),
        .y       (y),
        .hsync   (hsync),
        .vsync   (vsync),
        .active  (active)
    );

    assign border = (x < 10'd4) || (x >= 10'd636) || (y < 10'd4) || (y >= 10'd476);

    always @(*) begin
        red = 4'h0;
        green = 4'h0;
        blue = 4'h0;

        if (active) begin
            if (border) begin
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
        end
    end
endmodule
