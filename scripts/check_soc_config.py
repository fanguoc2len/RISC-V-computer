#!/usr/bin/env python3
"""Fail when RTL, firmware, or board defaults drift from soc_config.json."""

from __future__ import annotations

import re
from pathlib import Path

from soc_config import (
    BOOT_ROM_BASE,
    BOOT_ROM_SIZE_BYTES,
    BOOT_ROM_WORDS,
    GPIO_BASE,
    NPU_BASE,
    PS2_BASE,
    REPO_ROOT,
    SOC_CLK_FREQ_HZ,
    SPI_BASE,
    SRAM_BASE,
    SRAM_SIZE_BYTES,
    SRAM_WORDS,
    TIMER_BASE,
    TIMER_SIZE_BYTES,
    UART_BASE,
    UART_BAUD,
)


def parse_integer(token: str) -> int:
    token = token.strip().replace("_", "")
    verilog = re.fullmatch(r"(?:\d+)?'([hHdDbBoO])([0-9a-fA-F]+)", token)
    if verilog:
        radix = {"h": 16, "d": 10, "b": 2, "o": 8}[verilog.group(1).lower()]
        return int(verilog.group(2), radix)
    return int(re.sub(r"[uUlL]+$", "", token), 0)


def expect(path: Path, pattern: str, expected: int, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        raise SystemExit(f"{path}: could not find {label}")
    actual = parse_integer(match.group(1))
    if actual != expected:
        raise SystemExit(
            f"{path}: {label}=0x{actual:X}, manifest requires 0x{expected:X}"
        )


def main() -> None:
    platform = REPO_ROOT / "firmware" / "bootrom" / "platform.h"
    soc = REPO_ROOT / "rtl" / "soc" / "riscv_pc_soc.v"
    top = REPO_ROOT / "rtl" / "top" / "top_basys3.v"
    monitor_tb = REPO_ROOT / "tb" / "monitor_shell_tb.v"
    top_tb = REPO_ROOT / "tb" / "top_basys3_tb.v"

    c_values = {
        "SOC_CLK_FREQ_HZ": SOC_CLK_FREQ_HZ,
        "UART_BAUD": UART_BAUD,
        "SRAM_BASE": SRAM_BASE,
        "SRAM_SIZE_BYTES": SRAM_SIZE_BYTES,
        "UART_BASE": UART_BASE,
        "GPIO_BASE": GPIO_BASE,
        "TIMER_BASE": TIMER_BASE,
        "SPI_BASE": SPI_BASE,
        "PS2_BASE": PS2_BASE,
        "NPU_BASE": NPU_BASE,
    }
    for name, value in c_values.items():
        expect(platform, rf"^\s*#define\s+{name}\s+(\S+)", value, name)

    rtl_values = {
        "BOOT_ROM_BASE": BOOT_ROM_BASE,
        "SRAM_BASE": SRAM_BASE,
        "UART_BASE": UART_BASE,
        "GPIO_BASE": GPIO_BASE,
        "TIMER_BASE": TIMER_BASE,
        "SPI_BASE": SPI_BASE,
        "PS2_BASE": PS2_BASE,
        "NPU_BASE": NPU_BASE,
    }
    for name, value in rtl_values.items():
        expect(
            soc,
            rf"localparam\s+\[31:0\]\s+{name}\s*=\s*([^;]+);",
            value,
            name,
        )

    expect(soc, r"parameter\s+integer\s+BOOT_ROM_WORDS\s*=\s*([^,\n]+)", BOOT_ROM_WORDS, "BOOT_ROM_WORDS")
    expect(soc, r"parameter\s+integer\s+SRAM_WORDS\s*=\s*([^,\n]+)", SRAM_WORDS, "SRAM_WORDS")
    expect(top, r"\.CLK_FREQ_HZ\s*\(\s*([^)]+)\)", SOC_CLK_FREQ_HZ, "top SoC clock")
    expect(top, r"\.UART_BAUD\s*\(\s*([^)]+)\)", UART_BAUD, "top UART baud")
    expect(top, r"\.BOOT_ROM_WORDS\s*\(\s*([^)]+)\)", BOOT_ROM_WORDS, "top boot ROM words")
    expect(top, r"\.SRAM_WORDS\s*\(\s*([^)]+)\)", SRAM_WORDS, "top SRAM words")
    expect(monitor_tb, r"CLK_FREQ_HZ\s*=\s*([^;]+);", SOC_CLK_FREQ_HZ, "monitor clock")
    expect(monitor_tb, r"UART_BAUD\s*=\s*([^;]+);", UART_BAUD, "monitor UART baud")
    expect(top_tb, r"SOC_CLK_FREQ_HZ\s*=\s*CLK_FREQ_HZ\s*/\s*([^;]+);", 2, "top clock divisor")
    expect(
        top_tb,
        r"localparam\s+integer\s+CLK_FREQ_HZ\s*=\s*([^;]+);",
        SOC_CLK_FREQ_HZ * 2,
        "board clock",
    )
    expect(top_tb, r"UART_BAUD\s*=\s*([^;]+);", UART_BAUD, "top test UART baud")
    expect(
        soc,
        r"sel_timer\s*=\s*.*mem_addr\[4:2\]\s*<=\s*3'd(\d+)",
        (TIMER_SIZE_BYTES // 4) - 1,
        "timer last decoded word",
    )

    if BOOT_ROM_SIZE_BYTES != BOOT_ROM_WORDS * 4:
        raise SystemExit("manifest boot ROM byte and word sizes disagree")
    if SRAM_SIZE_BYTES != SRAM_WORDS * 4:
        raise SystemExit("manifest SRAM byte and word sizes disagree")

    print("PASS: RTL, firmware, generators, and testbench defaults match config/soc_config.json.")


if __name__ == "__main__":
    main()
