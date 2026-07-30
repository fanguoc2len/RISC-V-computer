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

yosys -q -p "
    read_verilog -sv -DSYNTHESIS ${rtl_files[*]};
    hierarchy -check -top top_basys3;
    synth_xilinx -family xc7 -top top_basys3;
    check -assert;
    stat
"

echo "Yosys Xilinx 7-series synthesis check passed"
