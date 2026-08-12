# AXI4-Lite validation flow for the Basys 3 design.
#
# Run from any directory:
#   vivado -mode batch -notrace \
#     -source scripts/run_vivado_axi_validation.tcl \
#     -tclargs 4
#
# The optional argument is the number of parallel synthesis/implementation
# jobs. Reports and the bitstream are written below build/.

set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set build_dir [file join $repo_dir build]
set report_dir [file join $build_dir axi_validation]
set project_dir [file join $report_dir vivado]
set summary_file [file join $report_dir axi_validation_status.txt]
set bridge_sim_log [file join $report_dir axi_bridge_sim.log]
set xsim_log [file join $project_dir risc_v_computer.sim sim_1 behav xsim simulate.log]
set bitfile [file join $project_dir risc_v_computer.runs impl_1 top_basys3.bit]

set jobs 4
if {$argc >= 1} {
    set requested_jobs [lindex $argv 0]
    if {![string is integer -strict $requested_jobs] || $requested_jobs < 1} {
        error "-tclargs value must be a positive integer, got '$requested_jobs'."
    }
    set jobs $requested_jobs
}

file mkdir $report_dir

set synth_status "NOT_RUN"
set impl_status "NOT_RUN"
set setup_slack "NA"
set hold_slack "NA"
set axi_cpu_cell_count 0
set axi_bridge_cell_count 0
set drc_error_count "NA"
set failure_details ""

proc read_text_file {path} {
    if {![file exists $path]} {
        error "Required file does not exist: $path"
    }

    set fh [open $path r]
    set contents [read $fh]
    close $fh
    return $contents
}

proc timing_slack_or_na {args} {
    set paths [get_timing_paths -quiet {*}$args]
    if {[llength $paths] == 0} {
        return "NA"
    }

    return [format "%.3f" [get_property SLACK [lindex $paths 0]]]
}

proc apply_run_strategy {run_name strategy_name} {
    set run_obj [get_runs -quiet $run_name]
    if {[llength $run_obj] == 0} {
        error "Vivado run '$run_name' was not created."
    }

    set available_strategies [list_property_value strategy $run_obj]
    if {[lsearch -exact $available_strategies $strategy_name] >= 0} {
        set_property strategy $strategy_name $run_obj
        puts "Using strategy $strategy_name for $run_name"
    } else {
        puts "WARNING: Strategy $strategy_name is unavailable for $run_name; using the project default."
    }
}

proc mark_wave_config_clean {} {
    set wave_config [current_wave_config]
    if {[string length $wave_config] > 0} {
        set_property needs_save false $wave_config
    }
}

proc write_validation_summary {status} {
    global summary_file synth_status impl_status setup_slack hold_slack
    global axi_cpu_cell_count axi_bridge_cell_count drc_error_count
    global bitfile bridge_sim_log failure_details

    set fh [open $summary_file w]
    puts $fh "axi_validation_status=$status"
    puts $fh "synth_status=$synth_status"
    puts $fh "impl_status=$impl_status"
    puts $fh "worst_setup_slack_ns=$setup_slack"
    puts $fh "worst_hold_slack_ns=$hold_slack"
    puts $fh "axi_cpu_cell_count=$axi_cpu_cell_count"
    puts $fh "axi_bridge_cell_count=$axi_bridge_cell_count"
    puts $fh "drc_error_count=$drc_error_count"
    puts $fh "bridge_sim_log=$bridge_sim_log"
    puts $fh "bitfile=$bitfile"
    puts $fh "bitfile_exists=[expr {[file exists $bitfile] ? 1 : 0}]"
    puts $fh "details=[string map [list \n { | } \r {}] $failure_details]"
    close $fh
}

if {[catch {
    cd $repo_dir

    # Fail early if the checked-in Basys 3 top-level is not selecting AXI.
    set top_source [read_text_file [file join $repo_dir rtl top top_basys3.v]]
    if {![regexp {\.USE_AXI[[:space:]]*\([[:space:]]*1[[:space:]]*\)} $top_source]} {
        error "top_basys3.v does not instantiate riscv_pc_soc with USE_AXI=1."
    }

    catch {mark_wave_config_clean}
    catch {close_sim}
    catch {close_project}
    set vivado_project_dir_override $project_dir
    source [file join $script_dir create_vivado_project.tcl]

    # First validate channel ordering, backpressure, byte strobes and DECERR.
    set_property top axi4lite_to_native_tb [get_filesets sim_1]
    update_compile_order -fileset sim_1
    launch_simulation -simset sim_1 -mode behavioral
    restart
    run all

    if {![file exists $xsim_log]} {
        error "AXI bridge simulation log was not generated: $xsim_log"
    }

    file copy -force $xsim_log $bridge_sim_log
    set bridge_log_contents [read_text_file $bridge_sim_log]
    if {[string first "PASS: AXI4-Lite to native bridge protocol checks completed." $bridge_log_contents] < 0} {
        error "AXI bridge simulation did not emit its PASS marker. See $bridge_sim_log"
    }
    if {[string first "FAIL:" $bridge_log_contents] >= 0} {
        error "AXI bridge simulation emitted a FAIL marker. See $bridge_sim_log"
    }

    catch {mark_wave_config_clean}
    catch {close_sim}

    # Re-select the board top and build through bitstream generation.
    set_property top top_basys3 [get_filesets sources_1]
    update_compile_order -fileset sources_1
    reset_run synth_1
    reset_run impl_1
    apply_run_strategy synth_1 Flow_PerfOptimized_high
    apply_run_strategy impl_1 Performance_ExplorePostRoutePhysOpt

    launch_runs synth_1 -jobs $jobs
    wait_on_run synth_1
    set synth_status [get_property STATUS [get_runs synth_1]]
    if {![string match "*Complete*" $synth_status]} {
        error "Vivado run 'synth_1' did not complete successfully: $synth_status"
    }

    open_run synth_1
    set axi_cpu_cells [get_cells -quiet -hier -filter {REF_NAME == picorv32_axi4lite}]
    set axi_bridge_cells [get_cells -quiet -hier -filter {REF_NAME == axi4lite_to_native}]
    set axi_cpu_cell_count [llength $axi_cpu_cells]
    set axi_bridge_cell_count [llength $axi_bridge_cells]
    report_utilization -hierarchical -file [file join $report_dir utilization_post_synth.rpt]
    close_design

    if {$axi_cpu_cell_count == 0 || $axi_bridge_cell_count == 0} {
        puts "WARNING: AXI hierarchy names were flattened in the synthesized netlist."
        puts "         USE_AXI=1 was verified in top_basys3.v before synthesis."
    } else {
        puts "Verified synthesized AXI hierarchy:"
        puts "  picorv32_axi4lite cells: $axi_cpu_cell_count"
        puts "  axi4lite_to_native cells: $axi_bridge_cell_count"
    }

    launch_runs impl_1 -to_step write_bitstream -jobs $jobs
    wait_on_run impl_1
    set impl_status [get_property STATUS [get_runs impl_1]]
    if {![string match "*Complete*" $impl_status]} {
        error "Vivado run 'impl_1' did not complete successfully: $impl_status"
    }

    open_run impl_1
    report_timing_summary \
        -delay_type min_max \
        -report_unconstrained \
        -check_timing_verbose \
        -file [file join $report_dir timing_summary_post_route.rpt]
    report_utilization \
        -hierarchical \
        -file [file join $report_dir utilization_post_route.rpt]
    report_drc -file [file join $report_dir drc_post_route.rpt]
    catch {
        report_methodology -file [file join $report_dir methodology_post_route.rpt]
    } methodology_error

    set setup_slack [timing_slack_or_na -setup -nworst 1 -max_paths 1]
    set hold_slack [timing_slack_or_na -hold -nworst 1 -max_paths 1]
    if {![catch {
        set drc_error_count [llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]
    }]} {
        puts "Post-route DRC error count: $drc_error_count"
    }

    if {![file exists $bitfile]} {
        error "Implementation completed but bitstream was not generated: $bitfile"
    }
    if {$setup_slack eq "NA"} {
        error "No constrained setup timing path was found."
    }
    if {$hold_slack eq "NA"} {
        error "No constrained hold timing path was found."
    }
    if {[expr {double($setup_slack) < 0.0}]} {
        error "Setup timing failed: WNS=$setup_slack ns"
    }
    if {[expr {double($hold_slack) < 0.0}]} {
        error "Hold timing failed: WHS=$hold_slack ns"
    }
    if {$drc_error_count ne "NA" && $drc_error_count > 0} {
        error "Post-route DRC contains $drc_error_count error(s)."
    }

    set failure_details "AXI bridge simulation, synthesis, implementation, DRC and timing passed."
    write_validation_summary PASS

    puts ""
    puts "AXI VALIDATION PASSED"
    puts "  setup WNS: $setup_slack ns"
    puts "  hold WHS:  $hold_slack ns"
    puts "  bitstream: $bitfile"
    puts "  summary:   $summary_file"
    puts "  reports:   $report_dir"

    close_project
} failure_details failure_options]} {
    puts stderr ""
    puts stderr "AXI VALIDATION FAILED"
    puts stderr "  $failure_details"
    catch {write_validation_summary FAIL}
    catch {mark_wave_config_clean}
    catch {close_sim}
    catch {close_project}
    puts stderr "  summary: $summary_file"
    puts stderr "  reports: $report_dir"
    return -code error $failure_details
}
