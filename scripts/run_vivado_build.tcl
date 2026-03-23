set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]

cd $repo_dir
source [file join $script_dir create_vivado_project.tcl]

reset_run synth_1
reset_run impl_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

open_run impl_1
report_timing_summary -file [file join $repo_dir build timing_summary_post_route.rpt]
report_utilization -file [file join $repo_dir build utilization_post_route.rpt]

close_project
exit
