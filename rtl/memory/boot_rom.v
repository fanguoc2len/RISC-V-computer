module boot_rom #(
    parameter integer WORDS = 4096,
    parameter MEMFILE = "bootrom.mem"
) (
    input  wire        clk,
    input  wire [31:0] addr,
    output reg  [31:0] rdata
);
    localparam integer ADDR_WIDTH = $clog2(WORDS);

    reg [31:0] mem [0:WORDS-1];
    integer i;

    initial begin
`ifndef SYNTHESIS
        // Fill unused simulation words with RISC-V NOPs. Synthesis only needs
        // the generated image below and must not unroll this large loop.
        for (i = 0; i < WORDS; i = i + 1) begin
            mem[i] = 32'h00000013;
        end
`endif
        $readmemh(MEMFILE, mem);
    end

    always @(posedge clk) begin
        rdata <= mem[addr[ADDR_WIDTH+1:2]];
    end
endmodule
