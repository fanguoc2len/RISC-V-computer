set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set build_dir [file join $repo_dir build]
set summary_file [file join $build_dir npu_regression_status.txt]
set monitor_log [file join $build_dir vivado_monitor_npu_regression.log]
set smoke_log [file join $build_dir vivado_smoke_npu_regression.log]

puts "Starting real Vivado/XSim demo flow..."
puts "This runs the actual RTL benches inside Vivado:"
puts "  - monitor_shell_tb"
puts "  - top_basys3_tb"

source [file join $script_dir run_vivado_npu_regression_core.tcl]

puts ""
puts "Real Vivado demo finished."
puts "Evidence files:"
puts "  $summary_file"
puts "  $monitor_log"
puts "  $smoke_log"
puts "Vivado stays open so you can inspect the project or logs."
