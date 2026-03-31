set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set demo_file [file join $repo_dir demo index.html]
set gen_script [file join $script_dir gen_offline_demo_data.py]

if {![file exists $demo_file]} {
    error "Offline demo was not found: $demo_file"
}

if {[file exists $gen_script]} {
    set native_gen_script [file nativename $gen_script]

    if {![catch {exec py -3 $native_gen_script} gen_output]} {
        puts $gen_output
    } elseif {![catch {exec python $native_gen_script} gen_output]} {
        puts $gen_output
    } else {
        puts "WARN: Could not regenerate demo/demo_data.js automatically. Using the checked-in copy."
    }
}

set native_demo_file [file nativename $demo_file]

if {$::tcl_platform(platform) eq "windows"} {
    set cmd_exe [auto_execok cmd]
    if {[string length $cmd_exe] == 0} {
        error "cmd.exe was not found in PATH."
    }
    exec {*}$cmd_exe /c start "" $native_demo_file &
} else {
    if {[catch {exec xdg-open $demo_file &}]} {
        puts "Open the offline demo manually:"
        puts "  $demo_file"
        return
    }
}

puts "Offline demo opened:"
puts "  $native_demo_file"
