set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set report_dir [file join $repo_dir build]
set bitfile [file join $repo_dir build vivado risc_v_computer.runs impl_1 top_basys3.bit]
set summary_file [file join $report_dir build_status.txt]

proc timing_slack_or_na {args} {
    set paths [get_timing_paths {*}$args]
    if {[llength $paths] == 0} {
        return "NA"
    }

    return [format "%.3f" [get_property SLACK [lindex $paths 0]]]
}

cd $repo_dir
source [file join $script_dir create_vivado_project.tcl]

reset_run synth_1
reset_run impl_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

open_run impl_1
report_timing_summary -file [file join $report_dir timing_summary_post_route.rpt]
report_utilization -file [file join $report_dir utilization_post_route.rpt]

set synth_status [get_property STATUS [get_runs synth_1]]
set impl_status [get_property STATUS [get_runs impl_1]]
set setup_slack [timing_slack_or_na -setup -nworst 1 -max_paths 1]
set hold_slack [timing_slack_or_na -hold -nworst 1 -max_paths 1]

set summary_fh [open $summary_file w]
puts $summary_fh "synth_status=$synth_status"
puts $summary_fh "impl_status=$impl_status"
puts $summary_fh "worst_setup_slack_ns=$setup_slack"
puts $summary_fh "worst_hold_slack_ns=$hold_slack"
puts $summary_fh "bitfile=$bitfile"
puts $summary_fh "bitfile_exists=[expr {[file exists $bitfile] ? 1 : 0}]"
close $summary_fh

puts "BUILD SUMMARY"
puts "  synth_status=$synth_status"
puts "  impl_status=$impl_status"
puts "  worst_setup_slack_ns=$setup_slack"
puts "  worst_hold_slack_ns=$hold_slack"
puts "  bitfile=$bitfile"

if {![file exists $bitfile]} {
    puts "ERROR: Bitstream was not generated."
} else {
    puts "GUI build finished. Vivado is still open."
    puts "Check:"
    puts "  $summary_file"
    puts "  [file join $report_dir timing_summary_post_route.rpt]"
    puts "  [file join $report_dir utilization_post_route.rpt]"
}
