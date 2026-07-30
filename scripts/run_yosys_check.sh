#!/usr/bin/env bash
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

rtl_files=(
    third_party/picorv32/picorv32.v
    rtl/bus/*.v
    rtl/memory/*.v
    rtl/peripherals/*.v
    rtl/soc/*.v
    rtl/top/*.v
    rtl/video/*.v
)

yosys_report="${TMPDIR:-/tmp}/riscv_yosys_resources_$$.json"
trap 'rm -f "$yosys_report"' EXIT

yosys -q -p "
    read_verilog -sv -DSYNTHESIS ${rtl_files[*]};
    hierarchy -check -top top_basys3;
    synth_xilinx -family xc7 -top top_basys3;
    check -assert;
    tee -o $yosys_report stat -json
"

python3 scripts/check_yosys_resources.py "$yosys_report"
