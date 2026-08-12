`timescale 1ns / 1ps

module picorv32_axi4lite #(
    parameter [0:0]  ENABLE_COUNTERS = 1,
    parameter [0:0]  BARREL_SHIFTER = 0,
    parameter [0:0]  COMPRESSED_ISA = 0,
    parameter [0:0]  ENABLE_PCPI = 0,
    parameter [0:0]  ENABLE_MUL = 0,
    parameter [0:0]  ENABLE_DIV = 0,
    parameter [0:0]  ENABLE_IRQ = 0,
    parameter [31:0] LATCHED_IRQ = 32'hffff_ffff,
    parameter [31:0] PROGADDR_RESET = 32'h0000_0000,
    parameter [31:0] PROGADDR_IRQ = 32'h0000_0010,
    parameter [31:0] STACKADDR = 32'hffff_ffff
) (
    input  wire        clk,
    input  wire        resetn,
    output wire        trap,
    output wire        axi_error,

    // AXI4-Lite master interface. PicoRV32 completes error responses just
    // like successful responses because its native bus has no fault signal.
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_awaddr,
    output wire [2:0]  m_axi_awprot,

    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,

    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    input  wire [1:0]  m_axi_bresp,

    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    output wire [31:0] m_axi_araddr,
    output wire [2:0]  m_axi_arprot,

    input  wire        m_axi_rvalid,
    output wire        m_axi_rready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,

    output wire        pcpi_valid,
    output wire [31:0] pcpi_insn,
    output wire [31:0] pcpi_rs1,
    output wire [31:0] pcpi_rs2,
    input  wire        pcpi_wr,
    input  wire [31:0] pcpi_rd,
    input  wire        pcpi_wait,
    input  wire        pcpi_ready,

    input  wire [31:0] irq,
    output wire [31:0] eoi
);
    wire trace_valid_unused;
    wire [35:0] trace_data_unused;

    // The bundled upstream adapter predates BRESP/RRESP ports. Report an
    // accepted non-OKAY response to the integration layer while allowing the
    // PicoRV32 native request to complete.
    assign axi_error =
        (m_axi_bvalid && m_axi_bready && (m_axi_bresp != 2'b00)) ||
        (m_axi_rvalid && m_axi_rready && (m_axi_rresp != 2'b00));

    picorv32_axi #(
        .PROGADDR_RESET  (PROGADDR_RESET),
        .PROGADDR_IRQ    (PROGADDR_IRQ),
        .STACKADDR       (STACKADDR),
        .ENABLE_MUL      (ENABLE_MUL),
        .ENABLE_DIV      (ENABLE_DIV),
        .BARREL_SHIFTER  (BARREL_SHIFTER),
        .COMPRESSED_ISA  (COMPRESSED_ISA),
        .ENABLE_COUNTERS (ENABLE_COUNTERS),
        .ENABLE_PCPI     (ENABLE_PCPI),
        .ENABLE_IRQ      (ENABLE_IRQ),
        .LATCHED_IRQ     (LATCHED_IRQ)
    ) cpu_i (
        .clk             (clk),
        .resetn          (resetn),
        .trap            (trap),
        .mem_axi_awvalid (m_axi_awvalid),
        .mem_axi_awready (m_axi_awready),
        .mem_axi_awaddr  (m_axi_awaddr),
        .mem_axi_awprot  (m_axi_awprot),
        .mem_axi_wvalid  (m_axi_wvalid),
        .mem_axi_wready  (m_axi_wready),
        .mem_axi_wdata   (m_axi_wdata),
        .mem_axi_wstrb   (m_axi_wstrb),
        .mem_axi_bvalid  (m_axi_bvalid),
        .mem_axi_bready  (m_axi_bready),
        .mem_axi_arvalid (m_axi_arvalid),
        .mem_axi_arready (m_axi_arready),
        .mem_axi_araddr  (m_axi_araddr),
        .mem_axi_arprot  (m_axi_arprot),
        .mem_axi_rvalid  (m_axi_rvalid),
        .mem_axi_rready  (m_axi_rready),
        .mem_axi_rdata   (m_axi_rdata),
        .pcpi_valid      (pcpi_valid),
        .pcpi_insn       (pcpi_insn),
        .pcpi_rs1        (pcpi_rs1),
        .pcpi_rs2        (pcpi_rs2),
        .pcpi_wr         (pcpi_wr),
        .pcpi_rd         (pcpi_rd),
        .pcpi_wait       (pcpi_wait),
        .pcpi_ready      (pcpi_ready),
        .irq             (irq),
        .eoi             (eoi),
        .trace_valid     (trace_valid_unused),
        .trace_data      (trace_data_unused)
    );

endmodule
