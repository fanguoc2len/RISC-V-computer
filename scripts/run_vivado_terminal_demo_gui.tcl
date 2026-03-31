set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set build_dir [file join $repo_dir build]
set sim_log [file join $repo_dir build vivado risc_v_computer.sim sim_1 behav xsim simulate.log]
set saved_log [file join $build_dir vivado_terminal_demo.log]
set transcript_file [file join $build_dir vivado_terminal_demo.txt]

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

proc write_text_file {path contents} {
    set fh [open $path w]
    puts -nonewline $fh $contents
    close $fh
}

proc extract_uart_transcript {contents} {
    set transcript ""

    foreach line [split $contents "\n"] {
        if {![regexp {UART monitor received byte 0x([0-9A-Fa-f]{2})} $line -> hex_byte]} {
            continue
        }

        scan $hex_byte %x byte_val

        if {$byte_val == 13} {
            continue
        } elseif {$byte_val == 10} {
            append transcript "\n"
        } elseif {$byte_val == 12} {
            append transcript "\n<CLEAR>\n"
        } elseif {$byte_val >= 32 && $byte_val <= 126} {
            append transcript [format %c $byte_val]
        }
    }

    set rv32_index [string first "RV32" $transcript]
    if {$rv32_index >= 0} {
        set transcript [string range $transcript $rv32_index end]
    }

    regsub -all {\n{3,}} $transcript "\n\n" transcript
    return [string trim $transcript]
}

cd $repo_dir
catch {mark_wave_config_clean}
catch {close_sim}
catch {close_project}

source [file join $script_dir create_vivado_project.tcl]

set_property top monitor_shell_tb [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "Starting real Vivado terminal demo with top=monitor_shell_tb"
launch_simulation -simset sim_1 -mode behavioral
restart
run all

if {![file exists $sim_log]} {
    error "Simulation log not found: $sim_log"
}

file copy -force $sim_log $saved_log
set log_contents [read_file_or_empty $saved_log]
set transcript [extract_uart_transcript $log_contents]

if {[string length $transcript] == 0} {
    set transcript "UART transcript could not be reconstructed from the simulation log."
}

write_text_file $transcript_file $transcript

puts ""
puts "===== UART Transcript ====="
puts $transcript
puts "==========================="

if {[string first "PASS: monitor shell simulation completed." $log_contents] < 0} {
    error "PASS marker 'PASS: monitor shell simulation completed.' was not found in $saved_log"
}

puts "Terminal demo PASSED."
puts "Saved files:"
puts "  $saved_log"
puts "  $transcript_file"
puts "Vivado stays open so you can inspect the run."
