set RP_PATH $arg1
set PRJ_NAME $arg2
set SOL_NAME $arg3
global PRJ_NAME SOL_NAME RP_PATH

proc read_nonblank_lines {path} {
    if {![file exists $path]} {
        error "Required file was not found: $path"
    }

    set fh [open $path r]
    set values {}
    while {[gets $fh line] != -1} {
        set trimmed [string trim $line]
        if {$trimmed eq ""} {
            continue
        }
        lappend values $trimmed
    }
    close $fh
    return $values
}

proc write_lines {path values} {
    set fh [open $path w]
    foreach value $values {
        puts $fh $value
    }
    close $fh
}

set root_dir [pwd]
set rprobe_dir [file join $root_dir $PRJ_NAME $SOL_NAME rprobe]
set impl_dir [file join $root_dir $PRJ_NAME $SOL_NAME impl ip hdl verilog]

set top_file [open "top.txt" r]
set topmodulename [string trim [read $top_file]]
close $top_file

set topupdated_file [open "top_updated.txt" r]
set topupdatedmodulename [string trim [read $topupdated_file]]
close $topupdated_file

if {$topmodulename eq ""} {
    error "top.txt is empty."
}
if {$topupdatedmodulename eq ""} {
    error "top_updated.txt is empty."
}

set selected_signals_file [file join $impl_dir "${topmodulename}_${topupdatedmodulename}_under.txt"]
set full_apstart_file [file join $rprobe_dir "apstart_signals.txt"]
set full_depth_file [file join $rprobe_dir "conservative_tripcount.txt"]

set selected_lines [read_nonblank_lines $selected_signals_file]
set selected_apstarts {}
foreach signal $selected_lines {
    if {[string match "*ap_start" $signal]} {
        lappend selected_apstarts $signal
    }
}

if {[llength $selected_apstarts] == 0} {
    error "No ap_start signals were found in $selected_signals_file"
}

set all_apstarts [read_nonblank_lines $full_apstart_file]
set all_depths [read_nonblank_lines $full_depth_file]

if {[llength $all_apstarts] != [llength $all_depths]} {
    error "apstart_signals.txt and conservative_tripcount.txt have different lengths"
}

set depth_map [dict create]
for {set i 0} {$i < [llength $all_apstarts]} {incr i} {
    dict set depth_map [lindex $all_apstarts $i] [lindex $all_depths $i]
}

set selected_depths {}
foreach signal $selected_apstarts {
    if {![dict exists $depth_map $signal]} {
        error "Could not map recorder depth for signal $signal"
    }
    lappend selected_depths [dict get $depth_map $signal]
}

set filtered_apstart_file [file join $rprobe_dir "update_apstart_signals.txt"]
set filtered_depth_file [file join $rprobe_dir "update_conservative_tripcount.txt"]
write_lines $filtered_apstart_file $selected_apstarts
write_lines $filtered_depth_file $selected_depths

set ::IPYNB_SIGNAL_FILE $filtered_apstart_file
set ::IPYNB_DEPTH_FILE $filtered_depth_file

source [file join $RP_PATH "ipynb_gen.tcl"]
