#!/usr/bin/env python3
import argparse
from pathlib import Path

from boot_image import MAGIC, build_image, sum32_le_words, validate_image
from soc_config import SRAM_BASE, SRAM_SIZE_BYTES


def parse_int(value: str) -> int:
    return int(value, 0)


def main() -> None:
    parser = argparse.ArgumentParser(description="Pack a raw RVPC boot image for the PicoRV32 FPGA computer.")
    parser.add_argument("input_bin", type=Path, help="Flat payload binary to load into SRAM.")
    parser.add_argument("output_img", type=Path, help="Output boot image containing header + payload.")
    parser.add_argument(
        "--load-addr",
        type=parse_int,
        default=SRAM_BASE,
        help=f"Destination SRAM address. Default: 0x{SRAM_BASE:08X}",
    )
    parser.add_argument("--entry-addr", type=parse_int, help="Entry point after load. Default: same as --load-addr")
    parser.add_argument("--version", type=parse_int, default=1, help="Header version field. Default: 1")
    args = parser.parse_args()

    payload = args.input_bin.read_bytes()
    entry_addr = args.entry_addr if args.entry_addr is not None else args.load_addr
    image = build_image(payload, args.load_addr, entry_addr, args.version)
    validate_image(
        image,
        sram_base=SRAM_BASE,
        sram_size_bytes=SRAM_SIZE_BYTES,
    )

    args.output_img.parent.mkdir(parents=True, exist_ok=True)
    args.output_img.write_bytes(image)

    print(f"Wrote raw boot image: {args.output_img}")
    print(f"  magic      = 0x{MAGIC:08X} ('RVPC')")
    print(f"  load_addr  = 0x{args.load_addr:08X}")
    print(f"  entry_addr = 0x{entry_addr:08X}")
    print(f"  size_bytes = {len(payload)}")
    print(f"  checksum   = 0x{sum32_le_words(payload):08X}")
    print(f"  total_size = {len(image)} bytes")


if __name__ == "__main__":
    main()
