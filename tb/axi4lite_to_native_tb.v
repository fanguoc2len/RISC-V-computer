`timescale 1ns / 1ps

module axi4lite_to_native_tb;
    reg clk;
    reg resetn;

    reg         awvalid;
    wire        awready;
    reg  [31:0] awaddr;
    reg  [2:0]  awprot;
    reg         wvalid;
    wire        wready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    wire        bvalid;
    reg         bready;
    wire [1:0]  bresp;
    reg         arvalid;
    wire        arready;
    reg  [31:0] araddr;
    reg  [2:0]  arprot;
    wire        rvalid;
    reg         rready;
    wire [31:0] rdata;
    wire [1:0]  rresp;

    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    reg  [31:0] mem_rdata;
    reg         mem_error;

    axi4lite_to_native dut (
        .clk           (clk),
        .resetn        (resetn),
        .s_axi_awvalid (awvalid),
        .s_axi_awready (awready),
        .s_axi_awaddr  (awaddr),
        .s_axi_awprot  (awprot),
        .s_axi_wvalid  (wvalid),
        .s_axi_wready  (wready),
        .s_axi_wdata   (wdata),
        .s_axi_wstrb   (wstrb),
        .s_axi_bvalid  (bvalid),
        .s_axi_bready  (bready),
        .s_axi_bresp   (bresp),
        .s_axi_arvalid (arvalid),
        .s_axi_arready (arready),
        .s_axi_araddr  (araddr),
        .s_axi_arprot  (arprot),
        .s_axi_rvalid  (rvalid),
        .s_axi_rready  (rready),
        .s_axi_rdata   (rdata),
        .s_axi_rresp   (rresp),
        .mem_valid     (mem_valid),
        .mem_instr     (mem_instr),
        .mem_ready     (mem_ready),
        .mem_addr      (mem_addr),
        .mem_wdata     (mem_wdata),
        .mem_wstrb     (mem_wstrb),
        .mem_rdata     (mem_rdata),
        .mem_error     (mem_error)
    );

    task tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task check_condition;
        input condition;
        input [8*80-1:0] message;
        begin
            if (!condition) begin
                $display("FAIL: %0s", message);
                $fatal(1);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        resetn = 1'b0;
        awvalid = 1'b0;
        awaddr = 32'h0000_0000;
        awprot = 3'b000;
        wvalid = 1'b0;
        wdata = 32'h0000_0000;
        wstrb = 4'b0000;
        bready = 1'b0;
        arvalid = 1'b0;
        araddr = 32'h0000_0000;
        arprot = 3'b000;
        rready = 1'b0;
        mem_ready = 1'b0;
        mem_rdata = 32'h0000_0000;
        mem_error = 1'b0;

        repeat (3) tick;
        resetn = 1'b1;
        tick;

        // Read address, native backpressure, then AXI response backpressure.
        araddr = 32'h1000_0040;
        arprot = 3'b100;
        arvalid = 1'b1;
        check_condition(arready, "AR channel was not ready while idle");
        tick;
        arvalid = 1'b0;
        check_condition(mem_valid, "read did not become a native request");
        check_condition(mem_instr, "ARPROT instruction bit was not preserved");
        check_condition(mem_addr == 32'h1000_0040, "read address changed");
        repeat (2) tick;
        check_condition(mem_valid, "native read did not survive backpressure");
        check_condition(mem_addr == 32'h1000_0040, "read address was not stable");

        mem_rdata = 32'h1234_5678;
        mem_ready = 1'b1;
        tick;
        mem_ready = 1'b0;
        check_condition(rvalid, "read response was not generated");
        check_condition(rdata == 32'h1234_5678, "read data was not returned");
        check_condition(rresp == 2'b00, "valid read did not return OKAY");
        tick;
        check_condition(rvalid, "RVALID was not held during backpressure");
        check_condition(rdata == 32'h1234_5678, "RDATA changed during backpressure");
        rready = 1'b1;
        tick;
        rready = 1'b0;
        check_condition(!rvalid, "read response did not retire");

        // Accept W before AW to verify independent write-channel handling.
        wdata = 32'hCAFE_BABE;
        wstrb = 4'b0101;
        wvalid = 1'b1;
        check_condition(wready, "W channel was not independently ready");
        tick;
        wvalid = 1'b0;
        check_condition(!mem_valid, "write started before its address arrived");

        awaddr = 32'h2000_1000;
        awprot = 3'b010;
        awvalid = 1'b1;
        check_condition(awready, "AW channel did not accept address after W");
        tick;
        awvalid = 1'b0;
        tick;
        check_condition(mem_valid, "write did not become a native request");
        check_condition(mem_addr == 32'h2000_1000, "write address mismatch");
        check_condition(mem_wdata == 32'hCAFE_BABE, "write data mismatch");
        check_condition(mem_wstrb == 4'b0101, "write strobe mismatch");

        mem_ready = 1'b1;
        tick;
        mem_ready = 1'b0;
        check_condition(bvalid, "write response was not generated");
        check_condition(bresp == 2'b00, "valid write did not return OKAY");
        tick;
        check_condition(bvalid, "BVALID was not held during backpressure");
        bready = 1'b1;
        tick;
        bready = 1'b0;
        check_condition(!bvalid, "write response did not retire");

        // Decode failures are visible to an AXI host as DECERR.
        araddr = 32'hF000_0000;
        arprot = 3'b000;
        arvalid = 1'b1;
        check_condition(arready, "AR channel was not ready for error test");
        tick;
        arvalid = 1'b0;
        check_condition(mem_valid, "error read did not reach native bus");
        mem_rdata = 32'hDEAD_BEEF;
        mem_error = 1'b1;
        mem_ready = 1'b1;
        tick;
        mem_ready = 1'b0;
        mem_error = 1'b0;
        check_condition(rvalid, "error read response was not generated");
        check_condition(rdata == 32'hDEAD_BEEF, "error read data mismatch");
        check_condition(rresp == 2'b11, "decode error did not return DECERR");
        rready = 1'b1;
        tick;

        $display("PASS: AXI4-Lite to native bridge protocol checks completed.");
        $finish;
    end
endmodule
