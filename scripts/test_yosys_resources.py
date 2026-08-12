#!/usr/bin/env python3
"""Unit tests for Yosys primitive accounting and resource ceilings."""

from __future__ import annotations

import unittest

from check_yosys_resources import resource_rows, summarize_cells


class YosysResourceTests(unittest.TestCase):
    def test_primitive_accounting(self) -> None:
        usage = summarize_cells(
            {
                "LUT1": 2,
                "LUT6": 3,
                "RAM64M": 4,
                "FDCE": 5,
                "FDRE": 7,
                "RAMB18E1": 3,
                "RAMB36E1": 4,
                "DSP48E1": 6,
            }
        )
        self.assertEqual(
            usage,
            {"lut": 21, "ff": 12, "bram18": 11, "dsp48": 6},
        )

    def test_eighty_percent_ceiling(self) -> None:
        rows = resource_rows(
            {"lut": 80, "ff": 81, "bram18": 8, "dsp48": 9},
            {"lut": 100, "ff": 100, "bram18": 10, "dsp48": 10},
            80,
        )
        failures = [name for name, used, ceiling, _capacity in rows if used > ceiling]
        self.assertEqual(failures, ["ff", "dsp48"])

    def test_invalid_budget_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "between 1 and 100"):
            resource_rows(
                {"lut": 0, "ff": 0, "bram18": 0, "dsp48": 0},
                {"lut": 1, "ff": 1, "bram18": 1, "dsp48": 1},
                101,
            )


if __name__ == "__main__":
    unittest.main()
