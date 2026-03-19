set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]

cd $repo_dir
source [file join $script_dir create_vivado_project.tcl]

launch_simulation -simset sim_1 -mode behavioral
restart
run all

close_sim
close_project
exit
