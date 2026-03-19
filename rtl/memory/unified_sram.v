module unified_sram #(
    parameter integer WORDS = 16384
) (
    input  wire        clk,
    input  wire [3:0]  wen,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata
);
    localparam integer ADDR_WIDTH = $clog2(WORDS);

    reg [31:0] mem [0:WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1) begin
            mem[i] = 32'h00000000;
        end
    end

    always @(posedge clk) begin
        rdata <= mem[addr[ADDR_WIDTH+1:2]];

        if (wen[0]) mem[addr[ADDR_WIDTH+1:2]][7:0]   <= wdata[7:0];
        if (wen[1]) mem[addr[ADDR_WIDTH+1:2]][15:8]  <= wdata[15:8];
        if (wen[2]) mem[addr[ADDR_WIDTH+1:2]][23:16] <= wdata[23:16];
        if (wen[3]) mem[addr[ADDR_WIDTH+1:2]][31:24] <= wdata[31:24];
    end
endmodule
