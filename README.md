# RISC-V Mini Computer on Basys 3 / Artix-7

[![Open Source Checks](https://github.com/fanguoc2len/RISC-V-computer/actions/workflows/open-source-checks.yml/badge.svg)](https://github.com/fanguoc2len/RISC-V-computer/actions/workflows/open-source-checks.yml)

This repository is an embedded-computer project built around `PicoRV32` on the
Digilent `Basys 3` board (`XC7A35T`, Artix-7). The goal is to grow a small but
real FPGA computer step by step instead of jumping straight into a full SoC.

At its current stage, the project is a practical FPGA bring-up platform with:

- `PicoRV32` CPU with an AXI4-Lite master path (native fallback retained)
- boot ROM + unified SRAM in BRAM
- UART monitor shell
- GPIO / LED / timer IRQ / SPI / PS2 peripherals
- VGA text console with status footer
- small NPU-style MMIO and PCPI test paths
- Vivado simulation flow, build scripts, and presentation demo

This repository consolidates the original Vivado project into a reproducible
source, documentation, and verification tree.

## Hardware Target

- Board: `Digilent Basys 3`
- FPGA: `xc7a35tcpg236-1`
- Board clock input: `100 MHz`
- SoC/AXI clock: `50 MHz`
- VGA pixel clock: `25 MHz`
- CPU: `PicoRV32`
- Memory model: unified address space

## What This Repo Demonstrates

The project is meant to show practical FPGA system work:

- top-level board integration
- AXI4-Lite CPU/interconnect integration
- memory-mapped peripheral design
- boot flow design
- host-verifiable regression paths
- documentation and scripted bring-up

The emphasis is on repeatable system bring-up and a clearly defined
architecture rather than an oversized, unfinished operating-system scope.

## Implemented Features

- boot ROM monitor image that can be simulated immediately
- raw-image SPI boot path
- UART command monitor
- PS/2 keyboard input path
- VGA text console `80x29` with live footer fields
- simple memory dump / timer / RAM self-test commands
- PicoRV32 external IRQ3 vector with a register-safe one-shot timer handler
- NPU-lite dot4, vector accumulate, and matvec4 validation paths
- SRAM app handoff via command `g` into `RVOS/32`

## Current Status

This repository is in the "working mini-computer bring-up" phase.

What is already in place:

- end-to-end Vivado simulation benches
- build scripts for Basys 3
- offline presentation demo for quick showcasing
- boot metadata flow through SRAM
- UART + SPI + PS/2 + VGA integrated in one top-level design

What is still intentionally modest:

- no external DDR
- no full SD card stack
- no OS-level runtime
- no cache / MMU / complex bus fabric

That tradeoff is deliberate. The repository prioritizes verifiable progress,
repeatable bring-up, and clear technical communication.

## Memory Map

| Address range | Function |
| --- | --- |
| `0x0000_0000` - `0x0000_3FFF` | Boot ROM (16 KB) |
| `0x1000_0000` - `0x1000_FFFF` | Unified SRAM (64 KB) |
| `0x2000_0000` - `0x2000_0007` | UART divider / data |
| `0x2000_1000` - `0x2000_1003` | GPIO output |
| `0x2000_2000` - `0x2000_2017` | Timer counter / compare / control / IRQ acknowledge count |
| `0x2000_3000` - `0x2000_3007` | SPI master |
| `0x2000_4000` - `0x2000_4007` | PS/2 keyboard |
| `0x2000_5000` - `0x2000_5027` | NPU-lite dot4 / matvec4 MMIO |

Clock, UART, ROM/SRAM size, and address-map defaults are defined in
`config/soc_config.json`. Run `python3 scripts/check_soc_config.py` after
changing RTL or firmware constants; CI runs the same drift check.

## Repository Layout

```text
rtl/
  bus/                       AXI4-Lite CPU wrapper and local-bus bridge
  top/top_basys3.v          Basys 3 top-level
  soc/riscv_pc_soc.v        main SoC
  memory/                   boot ROM and SRAM
  peripherals/              UART, GPIO, timer, SPI, PS/2, NPU-lite
  video/                    VGA timing and text console

tb/
  monitor_shell_tb.v
  top_basys3_tb.v

firmware/bootrom/
  boot ROM source

scripts/
  Vivado build, simulation, demo, and programming helpers

demo/
  host-side presentation companion
```

## Quick Start

### 1. Create the Vivado project

Open Vivado Tcl console:

```tcl
cd <repo-path>
source scripts/create_vivado_project.tcl
```

This creates the Basys 3 project, sets `top_basys3` as the synthesis top, and
sets `top_basys3_tb` as the default simulation top.

### 2. Run fast simulation checks

Fast monitor-shell regression:

```bat
scripts\run_vivado_monitor_sim.bat
```

Full smoke simulation:

```bat
scripts\run_vivado_smoke_sim.bat
```

AXI4-Lite protocol, synthesis, implementation, DRC, and timing validation:

```text
vivado -mode batch -notrace -source scripts/run_vivado_axi_validation.tcl -tclargs 4
```

NPU and top-level regression:

```bat
scripts\run_vivado_npu_regression.bat
```

### 3. Build for the board

```bat
scripts\run_vivado_build.bat
```

Expected summary files:

- `build/build_status.txt`
- `build/timing_summary_post_route.rpt`
- `build/utilization_post_route.rpt`

Expected bitstream:

```text
build\vivado\risc_v_computer.runs\impl_1\top_basys3.bit
```

### 4. Program the Basys 3 board

```bat
scripts\program_basys3.bat
```

### 5. Use the no-board demo if needed

```bat
scripts\run_offline_demo.bat
```

That demo is presentation-friendly, but the main evidence should still be the
Vivado simulation and build flow.

## Verification Signals To Look For

The current regression flow checks for concrete signs of life, including:

- `RV32` UART banner
- monitor help reply `CMDS:`
- `LED=0`
- `BOOT=OK`
- `PS2=OK`
- `RAM=OK`
- `NPU=OK`
- `PCPI=OK`
- `V16=OK`
- `MAT=OK`
- jump into `RVOS/32` and return to monitor

The reconstructed UART transcript is saved to:

```text
build/vivado_terminal_demo.txt
```

## Automated Checks

GitHub Actions runs hardware-independent checks for:

- deterministic regeneration of `bootrom.mem` and `boot_image.hex`
- RVPC header/range/checksum validation, including corrupted-payload rejection
- Verilator structural lint of the Basys 3 top-level RTL hierarchy
- Yosys synthesis of the complete top level for the Xilinx 7-series family,
  with an 80% LUT/FF/BRAM/DSP resource ceiling for the Basys 3
- AXI4-Lite bridge protocol behavior under channel and response backpressure
- timer MMIO counter/byte-strobe/compare/IRQ/EOI-count/W1C behavior
- monitor-shell boot from deliberately nonzero SRAM power-up contents
- full Basys 3 top-level end-to-end regression
- native CPU-bus fallback parity with the default AXI path

Vivado simulation, synthesis, implementation, and bitstream generation remain
in the documented local scripts because the proprietary toolchain is not
available on the standard GitHub-hosted runner.

Run the portable synthesis check locally with:

```bash
bash scripts/run_yosys_check.sh
```

The resource ceiling is defined in `config/fpga_resources.json`. It is an
early-growth guard based on the synthesized primitive estimate, not a
replacement for Vivado placement, routing, DRC, utilization, or timing.

## Why There Is Also a Zybo Repo

This repository is the **Basys 3 / Artix-7 mini-computer track**.

The separate repository `RISC-V-computer-ZYBO` is a different direction:
`Zynq PS + Linux + PL accelerators`. It is not the same board target and should
not be read as a replacement for this repo.

## Useful Docs

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/AXI4_LITE.md](docs/AXI4_LITE.md)
- [docs/INTERRUPTS.md](docs/INTERRUPTS.md)
- [docs/BOOT_FLOW.md](docs/BOOT_FLOW.md)
- [docs/BOARD_BRINGUP.md](docs/BOARD_BRINGUP.md)
- [docs/DEBUG_GUIDE.md](docs/DEBUG_GUIDE.md)
- [docs/ROADMAP.md](docs/ROADMAP.md)

## Project Summary

One-minute overview:

> I built a small RISC-V computer on a Basys 3 Artix-7 FPGA using PicoRV32,
> added memory-mapped peripherals, UART/SPI/PS2/VGA bring-up, a simple boot
> flow, and a Vivado-based regression path so the design can be demonstrated
> and debugged without depending only on hardware access.
