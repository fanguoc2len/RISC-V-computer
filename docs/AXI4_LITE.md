# AXI4-Lite integration

## Scope

The CPU path now supports a 32-bit AXI4-Lite master interface. The Basys 3
top-level enables it by default with `USE_AXI=1`:

```text
PicoRV32 native request
        |
picorv32_axi4lite
        |
AXI4-Lite AW/W/B + AR/R
        |
axi4lite_to_native
        |
existing ROM, SRAM and MMIO decoder
```

The bridge keeps the existing memory map and peripherals unchanged. Set
`USE_AXI=0` on `riscv_pc_soc` to instantiate the original native CPU path for
comparison or debugging.

## Supported behavior

- 32-bit address and data buses
- byte write strobes through `WSTRB`
- one outstanding transaction
- independent `AW` and `W` acceptance in either order
- stable native request until `mem_ready`
- stable `BVALID`, `RVALID`, `BRESP`, `RRESP`, and `RDATA` during backpressure
- `ARPROT[2]` forwarded as the PicoRV32 instruction-fetch attribute
- `OKAY` for mapped accesses
- `DECERR` for an address outside the SoC memory map

AXI4-Lite has no burst, ID, cache, QoS, or lock signals. The adapter therefore
connects naturally to control/status peripherals and BRAM, but it is not a
high-throughput DDR data path.

## Modules

`rtl/bus/picorv32_axi4lite.v` wraps the bundled PicoRV32 AXI adapter and exposes
a conventional AXI4-Lite master port, including `BRESP` and `RRESP`. The
`axi_error` output pulses when an accepted response is not `OKAY`. PicoRV32's
native memory port has no exception input, so the core still completes that
load/store. The SoC latches the pulse in bit 31 of `debug_boot_status`; the bit
remains set until reset, while bits 30:0 retain the firmware boot status.

`rtl/bus/axi4lite_to_native.v` is the AXI4-Lite slave used by this SoC. It
serializes each AXI request onto the existing PicoRV32-style local bus.

## Verification

The protocol test covers delayed native completion, read/write response
backpressure, `W` arriving before `AW`, byte strobes, instruction attributes,
and `DECERR` generation:

```sh
verilator --binary --timing \
  --top-module axi4lite_to_native_tb \
  rtl/bus/axi4lite_to_native.v \
  tb/axi4lite_to_native_tb.v \
  -Mdir /tmp/obj_axi_bridge

/tmp/obj_axi_bridge/Vaxi4lite_to_native_tb
```

The existing `top_basys3_tb` smoke test also runs with `USE_AXI=1`, exercising
boot ROM, SRAM, UART, GPIO, timer, SPI, PS/2, NPU MMIO, and PCPI through the AXI
path.

## Vivado synthesis and timing validation

Run the complete AXI validation flow from the repository root:

```sh
vivado -mode batch -notrace \
  -source scripts/run_vivado_axi_validation.tcl \
  -tclargs 4
```

The optional `-tclargs` value selects the number of parallel Vivado jobs. From
the Vivado Tcl Console, the equivalent command is:

```tcl
cd <repository-root>
source scripts/run_vivado_axi_validation.tcl
```

The script verifies that the board top selects `USE_AXI=1`, runs the AXI bridge
behavioral test, synthesizes and implements through bitstream generation, then
fails with a nonzero exit status on negative setup/hold slack, DRC errors, a
missing timing constraint, or a missing bitstream.

Results are written to:

```text
build/axi_validation/axi_validation_status.txt
build/axi_validation/axi_bridge_sim.log
build/axi_validation/utilization_post_synth.rpt
build/axi_validation/utilization_post_route.rpt
build/axi_validation/timing_summary_post_route.rpt
build/axi_validation/drc_post_route.rpt
build/axi_validation/vivado/risc_v_computer.runs/impl_1/top_basys3.bit
```

The validation project is separate from the normal `build/vivado` project, so
the regular Vivado GUI project can remain open while this batch flow runs.

The Basys 3 top uses the 100 MHz board oscillator to generate a 50 MHz SoC/AXI
clock and a 25 MHz VGA pixel clock. Both divided clocks are constrained in
`constraints/basys3_top.xdc`.
