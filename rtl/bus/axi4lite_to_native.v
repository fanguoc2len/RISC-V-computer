`timescale 1ns / 1ps

module axi4lite_to_native (
    input  wire        clk,
    input  wire        resetn,

    // AXI4-Lite slave interface.
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,

    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,

    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,
    output reg  [1:0]  s_axi_bresp,

    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    input  wire [31:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,

    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,

    // PicoRV32-style native memory request.
    output wire        mem_valid,
    output wire        mem_instr,
    input  wire        mem_ready,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [3:0]  mem_wstrb,
    input  wire [31:0] mem_rdata,
    input  wire        mem_error
);
    localparam [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam [1:0] AXI_RESP_DECERR = 2'b11;

    reg        aw_pending;
    reg [31:0] awaddr;
    reg        w_pending;
    reg [31:0] wdata;
    reg [3:0]  wstrb;

    reg        request_active;
    reg        request_write;
    reg [31:0] request_addr;
    reg        request_instr;
    reg [31:0] request_wdata;
    reg [3:0]  request_wstrb;

    wire response_pending = s_axi_bvalid || s_axi_rvalid;
    wire request_idle = !request_active && !response_pending;
    wire write_in_progress = aw_pending || w_pending;

    // A write has priority if either write channel is already pending or is
    // being presented now. This prevents accepting a read and a write in the
    // same cycle while still allowing AW and W to arrive independently.
    assign s_axi_awready = request_idle && !aw_pending;
    assign s_axi_wready  = request_idle && !w_pending;
    assign s_axi_arready = request_idle && !write_in_progress &&
                           !s_axi_awvalid && !s_axi_wvalid;

    assign mem_valid = request_active;
    assign mem_instr = !request_write && request_instr;
    assign mem_addr  = request_addr;
    assign mem_wdata = request_wdata;
    assign mem_wstrb = request_write ? request_wstrb : 4'b0000;

    always @(posedge clk) begin
        if (!resetn) begin
            aw_pending     <= 1'b0;
            awaddr         <= 32'h0000_0000;
            w_pending      <= 1'b0;
            wdata          <= 32'h0000_0000;
            wstrb          <= 4'b0000;
            request_active <= 1'b0;
            request_write  <= 1'b0;
            request_addr   <= 32'h0000_0000;
            request_instr  <= 1'b0;
            request_wdata  <= 32'h0000_0000;
            request_wstrb  <= 4'b0000;
            s_axi_bvalid   <= 1'b0;
            s_axi_bresp    <= AXI_RESP_OKAY;
            s_axi_rvalid   <= 1'b0;
            s_axi_rdata    <= 32'h0000_0000;
            s_axi_rresp    <= AXI_RESP_OKAY;
        end else begin
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end

            if (s_axi_awvalid && s_axi_awready) begin
                aw_pending <= 1'b1;
                awaddr <= s_axi_awaddr;
            end

            if (s_axi_wvalid && s_axi_wready) begin
                w_pending <= 1'b1;
                wdata <= s_axi_wdata;
                wstrb <= s_axi_wstrb;
            end

            if (s_axi_arvalid && s_axi_arready) begin
                request_active <= 1'b1;
                request_write <= 1'b0;
                request_addr <= s_axi_araddr;
                request_instr <= s_axi_arprot[2];
                request_wdata <= 32'h0000_0000;
                request_wstrb <= 4'b0000;
            end

            if (request_idle && aw_pending && w_pending) begin
                request_active <= 1'b1;
                request_write <= 1'b1;
                request_addr <= awaddr;
                request_instr <= 1'b0;
                request_wdata <= wdata;
                request_wstrb <= wstrb;
                aw_pending <= 1'b0;
                w_pending <= 1'b0;
            end

            if (request_active && mem_ready) begin
                request_active <= 1'b0;
                if (request_write) begin
                    s_axi_bvalid <= 1'b1;
                    s_axi_bresp <= mem_error ? AXI_RESP_DECERR : AXI_RESP_OKAY;
                end else begin
                    s_axi_rvalid <= 1'b1;
                    s_axi_rdata <= mem_rdata;
                    s_axi_rresp <= mem_error ? AXI_RESP_DECERR : AXI_RESP_OKAY;
                end
            end
        end
    end

    // AXI4-Lite protection attributes are accepted for compatibility. Only
    // ARPROT[2] is meaningful to the native bus (instruction fetch).
    wire _unused_awprot = ^s_axi_awprot;
endmodule
