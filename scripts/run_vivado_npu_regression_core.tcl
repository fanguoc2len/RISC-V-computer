set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set build_dir [file join $repo_dir build]
set sim_log [file join $repo_dir build vivado risc_v_computer.sim sim_1 behav xsim simulate.log]
set summary_file [file join $build_dir npu_regression_status.txt]

file mkdir $build_dir

proc mark_wave_config_clean {} {
    set curr_wave [current_wave_config]
    if {[string length $curr_wave] > 0} {
        set_property needs_save false $curr_wave
    }
}

proc read_file_or_empty {path} {
    if {![file exists $path]} {
        return ""
    }

    set fh [open $path r]
    set contents [read $fh]
    close $fh
    return $contents
}

proc write_regression_summary {status monitor_log smoke_log details} {
    global summary_file

    set fh [open $summary_file w]
    puts $fh "npu_regression_status=$status"
    puts $fh "monitor_log=$monitor_log"
    puts $fh "smoke_log=$smoke_log"
    puts $fh "details=$details"
    close $fh
}

proc run_checked_sim {sim_top pass_pattern saved_log label} {
    global sim_log

    catch {mark_wave_config_clean}
    catch {close_sim}

    set_property top $sim_top [get_filesets sim_1]
    update_compile_order -fileset sim_1

    puts "Starting $label with top=$sim_top"
    launch_simulation -simset sim_1 -mode behavioral
    restart
    run all

    if {![file exists $sim_log]} {
        error "Simulation log not found: $sim_log"
    }

    file copy -force $sim_log $saved_log
    set contents [read_file_or_empty $saved_log]

    if {[string first $pass_pattern $contents] < 0} {
        error "PASS marker '$pass_pattern' was not found in $saved_log"
    }

    puts "Verified $label"
    puts "  log: $saved_log"

    catch {mark_wave_config_clean}
    catch {close_sim}
}

set monitor_saved_log [file join $build_dir vivado_monitor_npu_regression.log]
set smoke_saved_log [file join $build_dir vivado_smoke_npu_regression.log]

cd $repo_dir
source [file join $script_dir create_vivado_project.tcl]

if {[catch {
    run_checked_sim monitor_shell_tb "PASS: monitor shell simulation completed." $monitor_saved_log "monitor shell regression"
    run_checked_sim top_basys3_tb "PASS: smoke simulation completed." $smoke_saved_log "top-level smoke regression"
} err]} {
    write_regression_summary FAIL $monitor_saved_log $smoke_saved_log $err
    puts "NPU regression FAILED."
    puts "Check:"
    puts "  $summary_file"
    puts "  $monitor_saved_log"
    puts "  $smoke_saved_log"
    error $err
}

write_regression_summary PASS $monitor_saved_log $smoke_saved_log "monitor_shell_tb + top_basys3_tb"
puts "NPU regression PASSED."
puts "Check:"
puts "  $summary_file"
puts "  $monitor_saved_log"
puts "  $smoke_saved_log"
