set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set build_dir [file join $repo_dir build vivado]

file mkdir $build_dir

create_project risc_v_computer $build_dir -part xc7a35tcpg236-1 -force
set_property target_language Verilog [current_project]

add_files [file join $repo_dir third_party picorv32 picorv32.v]
add_files [glob -nocomplain [file join $repo_dir rtl memory *.v]]
add_files [glob -nocomplain [file join $repo_dir rtl peripherals *.v]]
add_files [glob -nocomplain [file join $repo_dir rtl soc *.v]]
add_files [glob -nocomplain [file join $repo_dir rtl top *.v]]
add_files [glob -nocomplain [file join $repo_dir rtl video *.v]]
add_files [file join $repo_dir bootrom.mem]
add_files -fileset constrs_1 [file join $repo_dir constraints basys3_top.xdc]
add_files -fileset sim_1 [glob -nocomplain [file join $repo_dir tb *.v]]

set_property file_type {Memory Initialization Files} [get_files [file join $repo_dir bootrom.mem]]
set_property top top_basys3 [get_filesets sources_1]
set_property top top_basys3_tb [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset constrs_1
update_compile_order -fileset sim_1

puts "Vivado project created at $build_dir"
puts "Top module: top_basys3"
puts "Simulation top: top_basys3_tb"
