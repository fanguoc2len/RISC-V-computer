#!/usr/bin/env python3
"""Load the repository-wide SoC clock and address-map manifest."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPO_ROOT / "config" / "soc_config.json"


def _integer(value: Any) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        return int(value, 0)
    raise TypeError(f"Expected an integer or integer string, got {value!r}")


with CONFIG_PATH.open("r", encoding="utf-8") as config_file:
    _CONFIG = json.load(config_file)

SOC_CLK_FREQ_HZ = _integer(_CONFIG["soc_clock_hz"])
UART_BAUD = _integer(_CONFIG["uart_baud"])
REGIONS = _CONFIG["regions"]


def region_value(region: str, field: str) -> int:
    return _integer(REGIONS[region][field])


BOOT_ROM_BASE = region_value("boot_rom", "base")
BOOT_ROM_SIZE_BYTES = region_value("boot_rom", "size_bytes")
BOOT_ROM_WORDS = region_value("boot_rom", "words")
SRAM_BASE = region_value("sram", "base")
SRAM_SIZE_BYTES = region_value("sram", "size_bytes")
SRAM_WORDS = region_value("sram", "words")
UART_BASE = region_value("uart", "base")
GPIO_BASE = region_value("gpio", "base")
TIMER_BASE = region_value("timer", "base")
SPI_BASE = region_value("spi", "base")
PS2_BASE = region_value("ps2", "base")
NPU_BASE = region_value("npu", "base")


def validate_config() -> None:
    if SOC_CLK_FREQ_HZ <= 0:
        raise ValueError("soc_clock_hz must be positive")
    if UART_BAUD <= 0 or SOC_CLK_FREQ_HZ // UART_BAUD <= 0:
        raise ValueError("uart_baud must be positive and lower than soc_clock_hz")

    ranges: list[tuple[int, int, str]] = []
    for name, values in REGIONS.items():
        base = _integer(values["base"])
        size = _integer(values["size_bytes"])
        if base < 0 or base > 0xFFFFFFFF:
            raise ValueError(f"region {name}: base is outside the 32-bit address space")
        if base & 0x3:
            raise ValueError(f"region {name}: base must be 4-byte aligned")
        if size <= 0:
            raise ValueError(f"region {name}: size_bytes must be positive")
        end = base + size
        if end > 0x1_0000_0000:
            raise ValueError(f"region {name}: range exceeds the 32-bit address space")
        if "words" in values and _integer(values["words"]) * 4 != size:
            raise ValueError(
                f"region {name}: words * 4 does not equal size_bytes"
            )
        ranges.append((base, end, name))

    ranges.sort()
    for (_base_a, end_a, name_a), (base_b, _end_b, name_b) in zip(
        ranges, ranges[1:]
    ):
        if end_a > base_b:
            raise ValueError(f"regions {name_a} and {name_b} overlap")


validate_config()
