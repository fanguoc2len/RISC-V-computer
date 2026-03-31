#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path


def read_hex_bytes(path: Path) -> list[int]:
    return [int(token, 16) for token in path.read_text(encoding="ascii").split()]


def u32_le(data: list[int], offset: int) -> int:
    return (
        data[offset]
        | (data[offset + 1] << 8)
        | (data[offset + 2] << 16)
        | (data[offset + 3] << 24)
    )


def parse_define_u32(text: str, name: str) -> int:
    match = re.search(rf"#define\s+{re.escape(name)}\s+0x([0-9A-Fa-f]+)u", text)
    if not match:
        raise ValueError(f"Could not find define {name}")
    return int(match.group(1), 16)


def main() -> None:
    repo_dir = Path(__file__).resolve().parent.parent
    boot_image_path = repo_dir / "boot_image.hex"
    bootrom_c_path = repo_dir / "firmware" / "bootrom" / "bootrom.c"
    output_path = repo_dir / "demo" / "demo_data.js"

    boot_bytes = read_hex_bytes(boot_image_path)
    bootrom_c = bootrom_c_path.read_text(encoding="utf-8")

    data = {
        "title": "RV32 PC Offline Demo",
        "generatedAtUtc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "boot": {
            "magicText": "".join(chr(ch) for ch in boot_bytes[:4]),
            "loadAddress": f"{u32_le(boot_bytes, 4):08X}",
            "sizeBytes": f"{u32_le(boot_bytes, 8):08X}",
            "entryAddress": f"{u32_le(boot_bytes, 12):08X}",
            "checksum": f"{u32_le(boot_bytes, 16):08X}",
            "version": f"{u32_le(boot_bytes, 20):08X}",
            "reserved0": f"{u32_le(boot_bytes, 24):08X}",
            "reserved1": f"{u32_le(boot_bytes, 28):08X}",
            "bootInfoMagic": f"{parse_define_u32(bootrom_c, 'BOOT_INFO_MAGIC'):08X}",
            "statusOk": "00000001",
            "firstAppWord": f"{u32_le(boot_bytes, 32):08X}",
            "imageBytes": len(boot_bytes),
        },
        "npu": {
            "dot4": f"{parse_define_u32(bootrom_c, 'NPU_DEMO_EXPECT'):08X}",
            "vec16": f"{parse_define_u32(bootrom_c, 'NPU_VEC16_EXPECT'):08X}",
            "mat": [
                f"{parse_define_u32(bootrom_c, 'NPU_MAT4_EXPECT0'):08X}",
                f"{parse_define_u32(bootrom_c, 'NPU_MAT4_EXPECT1'):08X}",
                f"{parse_define_u32(bootrom_c, 'NPU_MAT4_EXPECT2'):08X}",
                f"{parse_define_u32(bootrom_c, 'NPU_MAT4_EXPECT3'):08X}",
            ],
        },
        "monitorCommands": ["h", "c", "l", "b", "k", "i", "m", "t", "r", "n", "p", "v", "x", "g"],
        "appCommands": ["h", "c", "i", "l", "t", "n", "v", "q"],
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        "window.RVPC_DEMO_DATA = " + json.dumps(data, indent=2) + ";\n",
        encoding="utf-8",
    )
    print(f"Wrote offline demo data to {output_path}")


if __name__ == "__main__":
    main()
