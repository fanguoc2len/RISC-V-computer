#!/usr/bin/env python3
"""Validate an RVPC boot image against the repository SRAM configuration."""

from __future__ import annotations

import argparse
from pathlib import Path

from boot_image import BootImageError, load_hex_bytes, validate_image
from soc_config import REPO_ROOT, SRAM_BASE, SRAM_SIZE_BYTES


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "image",
        nargs="?",
        type=Path,
        default=REPO_ROOT / "boot_image.hex",
        help="RVPC image (.hex uses one byte per token; other suffixes are binary).",
    )
    args = parser.parse_args()

    try:
        image = (
            load_hex_bytes(args.image)
            if args.image.suffix.lower() == ".hex"
            else args.image.read_bytes()
        )
        header, payload = validate_image(
            image,
            sram_base=SRAM_BASE,
            sram_size_bytes=SRAM_SIZE_BYTES,
        )
    except (BootImageError, OSError) as exc:
        raise SystemExit(f"FAIL: {args.image}: {exc}") from exc

    print(f"PASS: valid RVPC boot image: {args.image}")
    print(f"  load range = 0x{header.load_addr:08X}..0x{header.load_addr + len(payload) - 1:08X}")
    print(f"  entry      = 0x{header.entry_addr:08X}")
    print(f"  payload    = {len(payload)} bytes")
    print(f"  checksum   = 0x{header.checksum:08X}")


if __name__ == "__main__":
    main()
