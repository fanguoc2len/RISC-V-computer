#!/usr/bin/env python3
"""Unit tests for boot-ROM vectors and PicoRV32 custom IRQ opcodes."""

from __future__ import annotations

import unittest

from gen_bootrom import Program, build_boot_assets


class BootromGeneratorTests(unittest.TestCase):
    def test_custom_irq_instruction_encodings(self) -> None:
        program = Program()
        program.getq("t0", 2)
        program.setq(2, "t0")
        program.maskirq("zero", "t1")
        program.retirq()

        self.assertEqual(program.words[0], (2 << 15) | (5 << 7) | 0x0B)
        self.assertEqual(
            program.words[1],
            (0x01 << 25) | (5 << 15) | (2 << 7) | 0x0B,
        )
        self.assertEqual(
            program.words[2],
            (0x03 << 25) | (6 << 15) | 0x0B,
        )
        self.assertEqual(program.words[3], (0x02 << 25) | 0x0B)

    def test_reset_and_irq_vectors_are_fixed(self) -> None:
        words, _image = build_boot_assets()
        encoder = Program()

        self.assertEqual(words[0], encoder._encode_jal(0, 0x14))
        self.assertEqual(words[1:4], [0x00000013] * 3)
        self.assertEqual(words[4] & 0xFFF, 0x06F)

    def test_irq_handler_preserves_temporaries_and_returns(self) -> None:
        words, _image = build_boot_assets()
        setq_t0_q2 = (0x01 << 25) | (5 << 15) | (2 << 7) | 0x0B
        setq_t1_q3 = (0x01 << 25) | (6 << 15) | (3 << 7) | 0x0B
        getq_q3_t1 = (3 << 15) | (6 << 7) | 0x0B
        getq_q2_t0 = (2 << 15) | (5 << 7) | 0x0B
        retirq = (0x02 << 25) | 0x0B

        handler_start = words.index(setq_t0_q2)
        self.assertEqual(words[handler_start + 1], setq_t1_q3)
        restore_start = words.index(getq_q3_t1, handler_start)
        self.assertEqual(
            words[restore_start : restore_start + 3],
            [getq_q3_t1, getq_q2_t0, retirq],
        )


if __name__ == "__main__":
    unittest.main()
