#!/usr/bin/env python3
"""Check a post-synthesis Yosys JSON report against the Basys 3 budget."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Mapping


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG = REPO_ROOT / "config" / "fpga_resources.json"
RESOURCE_ORDER = ("lut", "ff", "bram18", "dsp48")
FF_PRIMITIVES = ("FDCE", "FDPE", "FDRE", "FDSE")
LUT_RAM_COST = {
    "RAM32M": 2,
    "RAM64M": 4,
}


def summarize_cells(cells: Mapping[str, int]) -> dict[str, int]:
    logic_luts = sum(int(cells.get(f"LUT{width}", 0)) for width in range(1, 7))
    memory_luts = sum(
        int(cells.get(primitive, 0)) * lut_cost
        for primitive, lut_cost in LUT_RAM_COST.items()
    )

    return {
        "lut": logic_luts + memory_luts,
        "ff": sum(int(cells.get(primitive, 0)) for primitive in FF_PRIMITIVES),
        "bram18": (
            int(cells.get("RAMB18E1", 0))
            + 2 * int(cells.get("RAMB36E1", 0))
        ),
        "dsp48": int(cells.get("DSP48E1", 0)),
    }


def resource_rows(
    usage: Mapping[str, int],
    capacity: Mapping[str, int],
    budget_percent: int,
) -> list[tuple[str, int, int, int]]:
    if not 1 <= budget_percent <= 100:
        raise ValueError("ci_budget_percent must be between 1 and 100")

    rows: list[tuple[str, int, int, int]] = []
    for resource in RESOURCE_ORDER:
        available = int(capacity[resource])
        if available <= 0:
            raise ValueError(f"capacity for {resource} must be positive")
        ceiling = available * budget_percent // 100
        rows.append((resource, int(usage[resource]), ceiling, available))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path, help="Yosys `stat -json` report")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    args = parser.parse_args()

    report = json.loads(args.report.read_text(encoding="utf-8"))
    config = json.loads(args.config.read_text(encoding="utf-8"))

    try:
        cells = report["design"]["num_cells_by_type"]
        budget_percent = int(config["ci_budget_percent"])
        rows = resource_rows(
            summarize_cells(cells),
            config["capacity"],
            budget_percent,
        )
    except (KeyError, TypeError, ValueError) as exc:
        raise SystemExit(f"FAIL: invalid Yosys resource report/config: {exc}") from exc

    print(
        f"Yosys resource estimate for {config['board']} "
        f"({config['part']}, CI ceiling {budget_percent}%):"
    )
    failures = []
    for resource, used, ceiling, available in rows:
        utilization = 100.0 * used / available
        print(
            f"  {resource.upper():6s} {used:5d} / {available:5d} "
            f"({utilization:5.1f}%, ceiling {ceiling})"
        )
        if used > ceiling:
            failures.append(
                f"{resource} uses {used}, above the {budget_percent}% ceiling {ceiling}"
            )

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        return 1

    print("PASS: Yosys resource estimate is within the Basys 3 CI budget.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
