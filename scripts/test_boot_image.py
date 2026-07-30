#!/usr/bin/env python3
"""Unit tests for RVPC boot-image packing and rejection paths."""

from __future__ import annotations

import unittest

from boot_image import BootImageError, HEADER_SIZE, build_image, validate_image


SRAM_BASE = 0x10000000
SRAM_SIZE = 0x00010000
LOAD_ADDR = SRAM_BASE + 0x20


class BootImageTests(unittest.TestCase):
    def validate(self, image: bytes):
        return validate_image(
            image,
            sram_base=SRAM_BASE,
            sram_size_bytes=SRAM_SIZE,
        )

    def test_round_trip(self) -> None:
        payload = bytes(range(1, 18))
        header, decoded = self.validate(
            build_image(payload, LOAD_ADDR, LOAD_ADDR)
        )
        self.assertEqual(decoded, payload)
        self.assertEqual(header.size_bytes, len(payload))

    def test_payload_tampering_is_rejected(self) -> None:
        image = bytearray(build_image(b"\x13\x00\x00\x00" * 4, LOAD_ADDR, LOAD_ADDR))
        image[HEADER_SIZE + 3] ^= 0x80
        with self.assertRaisesRegex(BootImageError, "checksum"):
            self.validate(bytes(image))

    def test_out_of_range_payload_is_rejected(self) -> None:
        image = build_image(b"\x00" * 8, SRAM_BASE + SRAM_SIZE - 4, SRAM_BASE + SRAM_SIZE - 4)
        with self.assertRaisesRegex(BootImageError, "outside SRAM"):
            self.validate(image)

    def test_entry_outside_payload_is_rejected(self) -> None:
        image = build_image(b"\x00" * 8, LOAD_ADDR, LOAD_ADDR + 8)
        with self.assertRaisesRegex(BootImageError, "entry address"):
            self.validate(image)


if __name__ == "__main__":
    unittest.main()
