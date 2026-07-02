# RISC-V Mini Computer on Basys 3 / Artix-7

This repository is an embedded-computer project built around `PicoRV32` on the
Digilent `Basys 3` board (`XC7A35T`, Artix-7). The goal is to grow a small but
real FPGA computer step by step instead of jumping straight into a full SoC.

At its current stage, the project already looks like a serious student bring-up
platform rather than a toy RTL dump:

- `PicoRV32` CPU with native memory interface
- boot ROM + unified SRAM in BRAM
- UART monitor shell
- GPIO / LED / timer / SPI / PS2 peripherals
- VGA text console with status footer
- small NPU-style MMIO and PCPI test paths
- Vivado simulation flow, build scripts, and presentation demo

This repo is the cleaned-up, portfolio-ready version of the original local
Vivado project under `E:\riscvpicorv32\RISC_V_PicoRV32`.

## Hardware Target

- Board: `Digilent Basys 3`
- FPGA: `xc7a35tcpg236-1`
- Clock: `100 MHz`
- CPU: `PicoRV32`
- Memory model: unified address space

## What This Repo Demonstrates

The project is meant to show practical FPGA system work:

- top-level board integration
- memory-mapped peripheral design
- boot flow design
- host-verifiable regression paths
- documentation and scripted bring-up

For internship or graduation-project review, that matters more than trying to
look like a huge unfinished operating-system project.

## Implemented Features

- boot ROM monitor image that can be simulated immediately
- raw-image SPI boot path
- UART command monitor
- PS/2 keyboard input path
- VGA text console `80x29` with live footer fields
- simple memory dump / timer / RAM self-test commands
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

That tradeoff is deliberate. The repo optimizes for believable progress,
repeatable bring-up, and easy explanation in an interview.

## Memory Map

| Address range | Function |
| --- | --- |
| `0x0000_0000` - `0x0000_3FFF` | Boot ROM (16 KB) |
| `0x1000_0000` - `0x1000_FFFF` | Unified SRAM (64 KB) |
| `0x2000_0000` - `0x2000_0007` | UART divider / data |
| `0x2000_1000` - `0x2000_1003` | GPIO output |
| `0x2000_2000` - `0x2000_2013` | Timer counter / compare |
| `0x2000_3000` - `0x2000_3007` | SPI master |
| `0x2000_4000` - `0x2000_4007` | PS/2 keyboard |
| `0x2000_5000` - `0x2000_5027` | NPU-lite dot4 / matvec4 MMIO |

## Repository Layout

```text
rtl/
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

## Why There Is Also a Zybo Repo

This repository is the **Basys 3 / Artix-7 mini-computer track**.

The separate repository `RISC-V-computer-ZYBO` is a different direction:
`Zynq PS + Linux + PL accelerators`. It is not the same board target and should
not be read as a replacement for this repo.

## Useful Docs

- [docs/ARCHITECTURE.md](/home/fanguoc2len/code/RISC-V-computer/docs/ARCHITECTURE.md)
- [docs/BOOT_FLOW.md](/home/fanguoc2len/code/RISC-V-computer/docs/BOOT_FLOW.md)
- [docs/BOARD_BRINGUP.md](/home/fanguoc2len/code/RISC-V-computer/docs/BOARD_BRINGUP.md)
- [docs/DEBUG_GUIDE.md](/home/fanguoc2len/code/RISC-V-computer/docs/DEBUG_GUIDE.md)
- [docs/ROADMAP.md](/home/fanguoc2len/code/RISC-V-computer/docs/ROADMAP.md)

## Interview Summary

If you need to explain this repo in one minute:

> I built a small RISC-V computer on a Basys 3 Artix-7 FPGA using PicoRV32,
> added memory-mapped peripherals, UART/SPI/PS2/VGA bring-up, a simple boot
> flow, and a Vivado-based regression path so the design can be demonstrated
> and debugged without depending only on hardware access.
