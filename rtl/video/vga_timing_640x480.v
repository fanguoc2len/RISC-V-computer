module vga_timing_640x480 (
    input  wire       clk_pix,
    input  wire       resetn,
    output reg [9:0]  x,
    output reg [9:0]  y,
    output wire       hsync,
    output wire       vsync,
    output wire       active
);
    localparam H_VISIBLE = 10'd640;
    localparam H_FRONT   = 10'd16;
    localparam H_SYNC    = 10'd96;
    localparam H_BACK    = 10'd48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam V_VISIBLE = 10'd480;
    localparam V_FRONT   = 10'd10;
    localparam V_SYNC    = 10'd2;
    localparam V_BACK    = 10'd33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    always @(posedge clk_pix or negedge resetn) begin
        if (!resetn) begin
            x <= 10'd0;
            y <= 10'd0;
        end else if (x == H_TOTAL - 1) begin
            x <= 10'd0;
            if (y == V_TOTAL - 1) begin
                y <= 10'd0;
            end else begin
                y <= y + 10'd1;
            end
        end else begin
            x <= x + 10'd1;
        end
    end

    assign active = (x < H_VISIBLE) && (y < V_VISIBLE);
    assign hsync = ~((x >= H_VISIBLE + H_FRONT) && (x < H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync = ~((y >= V_VISIBLE + V_FRONT) && (y < V_VISIBLE + V_FRONT + V_SYNC));
endmodule
