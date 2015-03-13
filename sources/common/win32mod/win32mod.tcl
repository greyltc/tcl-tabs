namespace eval tabs {}

proc tabs::decodeWin32Icon {dat} {
    set result {}
    binary scan $dat sss - type count
    for {set pos 6} {[incr count -1] >= 0} {incr pos 16} {
        binary scan $dat @${pos}ccccssii w h cc - p bc bir io
        if {$cc == 0} { 
            if {$bc == 0} {
                set cc 256
            }  else  {
                set cc "${bc}b"
            }
        }
        binary scan $dat @${io}a$bir image
        lappend result ${w}x${h}/$cc/$bir $image
    }
    return $result
}


proc tabs::applyWin32Icons {filedata origicondata icons manager} {
    if {[string range $filedata 0 1] != "MZ"} {
        return $filedata
    }

    # replace icons if specified
    if {([llength $icons] > 0) && ([string length $origicondata] > 0)} {
        foreach icofile $icons {
            set fh [open $icofile r]
            fconfigure $fh -translation binary
            set newicondata [read $fh]
            close $fh

            array set newicon [decodeWin32Icon $newicondata]
        }

        foreach {key data} [decodeWin32Icon $origicondata] {
            if {[info exists newicon($key)]} {
                if {$manager != {}} {
                    $manager Printlog 5 "Replacing icon: $key"
                }
                if {[string length $data] != [string length $newicon($key)]} {
                }  else  {
                    set offset0 [string first $data $filedata]
                    set offset1 [expr {$offset0 + [string length $data] - 1}]
                    if {$offset0 >= 0} {
                        set filedata [string replace $filedata $offset0 $offset1 $newicon($key)]
                    }
                }
            }  else  {
                if {$manager != {}} {
                    $manager Printlog 5 "Icon not found: $key"
                }
            }
        }
    }

    return $filedata
}

proc tabs::setWin32fileinfo {filename fileinfo} {
    if {[llength $fileinfo] > 0} {
        array set a $fileinfo
        package require stringfileinfo
        stringfileinfo::writeStringInfo $filename a
    }
}

package provide tabs::win32mod 1.0
