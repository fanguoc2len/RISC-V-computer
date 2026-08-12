#!/usr/bin/env python3
"""Shared RVPC boot-image packing and validation helpers."""

from __future__ import annotations

import struct
from dataclasses import dataclass
from pathlib import Path


MAGIC = int.from_bytes(b"RVPC", "little")
VERSION = 1
HEADER_WORDS = 8
HEADER_SIZE = HEADER_WORDS * 4


class BootImageError(ValueError):
    """Raised when an RVPC boot image violates the checked format."""


@dataclass(frozen=True)
class BootImageHeader:
    magic: int
    load_addr: int
    size_bytes: int
    entry_addr: int
    checksum: int
    version: int
    reserved0: int
    reserved1: int


def sum32_le_words(payload: bytes | bytearray | list[int]) -> int:
    payload_bytes = bytes(payload)
    padded = payload_bytes + bytes((-len(payload_bytes)) % 4)
    checksum = 0
    for offset in range(0, len(padded), 4):
        checksum = (
            checksum + int.from_bytes(padded[offset : offset + 4], "little")
        ) & 0xFFFFFFFF
    return checksum


def build_image(
    payload: bytes | bytearray | list[int],
    load_addr: int,
    entry_addr: int,
    version: int = VERSION,
) -> bytes:
    payload_bytes = bytes(payload)
    header = struct.pack(
        "<8I",
        MAGIC,
        load_addr & 0xFFFFFFFF,
        len(payload_bytes) & 0xFFFFFFFF,
        entry_addr & 0xFFFFFFFF,
        sum32_le_words(payload_bytes),
        version & 0xFFFFFFFF,
        0,
        0,
    )
    return header + payload_bytes


def load_hex_bytes(path: Path) -> bytes:
    """Load the one-byte-per-token format consumed by the SPI test models."""
    result = bytearray()
    for line_number, line in enumerate(
        path.read_text(encoding="ascii").splitlines(), start=1
    ):
        content = line.split("//", 1)[0].strip()
        if not content:
            continue
        for token in content.split():
            if len(token) != 2:
                raise BootImageError(
                    f"{path}:{line_number}: expected a two-digit byte, got {token!r}"
                )
            try:
                value = int(token, 16)
            except ValueError as exc:
                raise BootImageError(
                    f"{path}:{line_number}: invalid hexadecimal byte {token!r}"
                ) from exc
            result.append(value)
    return bytes(result)


def validate_image(
    image: bytes,
    *,
    sram_base: int,
    sram_size_bytes: int,
) -> tuple[BootImageHeader, bytes]:
    if len(image) < HEADER_SIZE:
        raise BootImageError(
            f"image is {len(image)} bytes; the RVPC header requires {HEADER_SIZE}"
        )

    header = BootImageHeader(*struct.unpack("<8I", image[:HEADER_SIZE]))
    payload = image[HEADER_SIZE:]

    if header.magic != MAGIC:
        raise BootImageError(
            f"bad magic 0x{header.magic:08X}; expected 0x{MAGIC:08X} ('RVPC')"
        )
    if header.version != VERSION:
        raise BootImageError(
            f"unsupported version {header.version}; expected {VERSION}"
        )
    if header.reserved0 != 0 or header.reserved1 != 0:
        raise BootImageError("reserved header words must be zero")
    if header.size_bytes == 0:
        raise BootImageError("payload must not be empty")
    if len(payload) != header.size_bytes:
        raise BootImageError(
            f"payload length is {len(payload)} bytes; header says {header.size_bytes}"
        )
    if header.load_addr & 0x3:
        raise BootImageError("load address must be 4-byte aligned")
    if header.entry_addr & 0x3:
        raise BootImageError("entry address must be 4-byte aligned")

    sram_end = sram_base + sram_size_bytes
    payload_end = header.load_addr + header.size_bytes
    if header.load_addr < sram_base or payload_end > sram_end:
        raise BootImageError(
            "payload range "
            f"0x{header.load_addr:08X}..0x{payload_end - 1:08X} "
            f"is outside SRAM 0x{sram_base:08X}..0x{sram_end - 1:08X}"
        )
    if not (header.load_addr <= header.entry_addr < payload_end):
        raise BootImageError("entry address is outside the payload range")

    actual_checksum = sum32_le_words(payload)
    if actual_checksum != header.checksum:
        raise BootImageError(
            f"checksum is 0x{actual_checksum:08X}; "
            f"header requires 0x{header.checksum:08X}"
        )

    return header, payload
