package require Tcl 8.5
package require tdom

rename csynth_design original_csynth_design
rename export_design original_export_design
rename cosim_design original_cosim_design

set RP_PATH $arg1 
set BUILD_PATH $arg2 
set PRJ_NAME $arg3 
set SOL_NAME $arg4 
set TARGET_DEV $arg5

proc csynth_design {} {
    global BUILD_PATH

    set ::env(XILINX_OPEN_SOURCE_LLVM_BUILD_PATH) $BUILD_PATH
    check_rp 
    original_csynth_design
}

proc export_design {args} {
    global RP_PATH

    original_export_design -format ip_catalog
    run_rp $RP_PATH
}

proc filter_ld_library_path {ldPath} {
    set filtered {}
    foreach entry [split $ldPath ":"] {
        if {$entry eq ""} {
            continue
        }
        if {[string match "*/Vitis_HLS/*/lib/lnx64.o/*" $entry]} {
            continue
        }
        lappend filtered $entry
    }
    return [join $filtered ":"]
}

proc cosim_design {args} {
    global BUILD_PATH
    set hadLdPath [info exists ::env(LD_LIBRARY_PATH)]
    if {$hadLdPath} {
        set originalLdPath $::env(LD_LIBRARY_PATH)
        set filteredLdPath [filter_ld_library_path $originalLdPath]
        set localRuntimeLibPath [file normalize [file join [pwd] ".linux-hls-libs"]]
        if {[file isdirectory $localRuntimeLibPath]} {
            set ::env(LD_LIBRARY_PATH) "${localRuntimeLibPath}:$filteredLdPath"
        } else {
            set ::env(LD_LIBRARY_PATH) $filteredLdPath
        }
    }

    set cmd [linsert $args 0 original_cosim_design]
    set status [catch {uplevel 1 $cmd} result options]

    if {$hadLdPath} {
        set ::env(LD_LIBRARY_PATH) $originalLdPath
    }

    if {$status} {
        return -options $options $result
    }
    return $result
}


proc check_rp {} {
    global PRJ_NAME
    global SOL_NAME

    set filename "[pwd]/$PRJ_NAME/$SOL_NAME/.autopilot/db/fe_messages.xml"
    if {[file exists $filename]} {
        puts "File $filename found, processing now..."
        set result [process_file $filename]

        if {$result ne 0} {
            set file [open "[pwd]/$PRJ_NAME/$SOL_NAME/.autopilot/db/realprobe_found.txt" w]
            puts $file $result
            close $file
            puts "Result written to realprobe_found.txt"
        }
    } else {
        puts "File $filename not found."
        after 5000 check_rp
    }
}

proc run_rp {sourceDir} {
    global PRJ_NAME
    global SOL_NAME
    global RP_PATH
    global BUILD_PATH
    global TARGET_DEV

    set rprobefnd "[pwd]/$PRJ_NAME/$SOL_NAME/.autopilot/db/realprobe_found.txt"
    if {[file exists $rprobefnd]} {
        # puts "File $rprobefnd found, processing now..."
        # set destDir "[pwd]/$PRJ_NAME/$SOL_NAME"
        # foreach file [glob -directory $sourceDir *] {
        #     set srcFile $file
        #     set destFile [file join $destDir [file tail $srcFile]]

        #     file copy -force $srcFile $destFile
        # }
        source "$RP_PATH/realprobe.tcl"
        puts "RealProbe run"
    } else {
        puts "File $rprobefnd not found."
    }
}

proc process_file {filename} {
    set fp [open $filename r]
    set data [read $fp]
    close $fp

    set doc [dom parse $data]
    set root [$doc documentElement]

    foreach msg [$root selectNodes {msg}] {
        set pragmaTypeNodes [$msg selectNodes {args/@ARG_PragmaType}]

        set words [split [string trim $pragmaTypeNodes "{}"]]
        set lastWord [lindex $words end]

        if {$lastWord eq "realprobe"} {
            set msgLocNode [$msg selectNodes {@msg_loc}]
            set pragmaFunctionNode [$msg selectNodes {args/@ARG_PragmaFunction}]
            set funcwords [split [string trim $pragmaFunctionNode "{}"]]
            set lastfuncWord [lindex $funcwords end]

            return $lastfuncWord
            # if {[regexp {:(\d+):} $msgLocNode -> lineNumber]} {
            #     puts "The line number is: $lineNumber"
            # } else {
            #     puts "No line number found."
            # }
        }
    }
    $doc delete
    return 0
}
