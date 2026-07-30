`timescale 1ns / 1ps

module timer_mmio_tb;
    reg         clk;
    reg         resetn;
    reg         valid;
    reg  [31:0] addr;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    wire        ready;
    wire [31:0] rdata;
    wire        irq;
    wire [31:0] debug_counter_lo;

    timer_mmio dut (
        .clk              (clk),
        .resetn           (resetn),
        .valid            (valid),
        .addr             (addr),
        .wdata            (wdata),
        .wstrb            (wstrb),
        .ready            (ready),
        .rdata            (rdata),
        .irq              (irq),
        .debug_counter_lo (debug_counter_lo)
    );

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_condition;
        input condition;
        input [8*80-1:0] message;
        begin
            if (!condition) begin
                $display("FAIL: %0s", message);
                $fatal(1);
            end
        end
    endtask

    task automatic mmio_write;
        input [4:0] offset;
        input [31:0] data;
        input [3:0] strobes;
        begin
            addr = {27'd0, offset};
            wdata = data;
            wstrb = strobes;
            valid = 1'b1;
            tick;
            check_condition(ready, "timer write did not acknowledge");
            valid = 1'b0;
            wstrb = 4'b0000;
            tick;
        end
    endtask

    task automatic mmio_read;
        input [4:0] offset;
        output [31:0] data;
        begin
            addr = {27'd0, offset};
            wdata = 32'd0;
            wstrb = 4'b0000;
            valid = 1'b1;
            tick;
            check_condition(ready, "timer read did not acknowledge");
            data = rdata;
            valid = 1'b0;
            tick;
        end
    endtask

    reg [31:0] first_count;
    reg [31:0] second_count;
    reg [31:0] value;
    integer wait_cycles;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        resetn = 1'b0;
        valid = 1'b0;
        addr = 32'd0;
        wdata = 32'd0;
        wstrb = 4'd0;

        repeat (3) tick;
        resetn = 1'b1;
        tick;
        check_condition(!irq, "IRQ was asserted after reset");

        mmio_read(5'h00, first_count);
        repeat (3) tick;
        mmio_read(5'h00, second_count);
        check_condition(second_count > first_count, "counter did not advance");

        // Verify individual byte strobes on compare-low.
        mmio_write(5'h08, 32'h1122_3344, 4'b1111);
        mmio_write(5'h08, 32'h00AA_0000, 4'b0100);
        mmio_read(5'h08, value);
        check_condition(value == 32'h11AA_3344, "compare byte strobes were not honored");

        // Program a near-future compare value and enable the interrupt output.
        mmio_write(5'h0C, 32'd0, 4'b1111);
        mmio_write(5'h08, debug_counter_lo + 32'd12, 4'b1111);
        mmio_write(5'h10, 32'h0000_0002, 4'b0001);

        wait_cycles = 0;
        while (!irq && wait_cycles < 40) begin
            tick;
            wait_cycles = wait_cycles + 1;
        end
        check_condition(irq, "compare event did not assert IRQ");
        mmio_read(5'h10, value);
        check_condition(value[1:0] == 2'b11, "status did not report enabled + pending");

        // Disable the compare source, then clear pending with W1C while retaining enable.
        mmio_write(5'h08, 32'd0, 4'b1111);
        mmio_write(5'h10, 32'h0000_0003, 4'b0001);
        check_condition(!irq, "W1C did not clear the pending interrupt");
        mmio_read(5'h10, value);
        check_condition(value[1:0] == 2'b10, "control state after W1C was incorrect");

        $display("PASS: timer MMIO counter, strobes, compare, IRQ and W1C checks completed.");
        $finish;
    end
endmodule
