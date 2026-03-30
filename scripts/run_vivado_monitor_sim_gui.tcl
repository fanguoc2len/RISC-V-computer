set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]

cd $repo_dir
source [file join $script_dir create_vivado_project.tcl]

set_property top monitor_shell_tb [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation -simset sim_1 -mode behavioral
restart
run all

puts "GUI monitor shell simulation finished. Vivado is still open."
