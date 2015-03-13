package require snit
package require fileutil
package require tabs::vfshandler

namespace eval tabs {}

snit::type tabs::job::split {
    option -manager

    option -file -default ""
    option -head -default ""
    option -tail -default ""
    
    constructor {args} {
        $self configurelist $args
    }
    
    method label {} {
        return "split [$self cget -file]"
    }

    method inputs {} {
        return [list [$self cget -file]]
    }

    method outputs {} {
        set rc [list]
        if {[$self cget -head] != ""} {
            lappend rc [$self cget -head]
        }
        if {[$self cget -tail] != ""} {
            lappend rc [$self cget -tail]
        }
        return $rc
    }

    method execute {} {
        set file [$self cget -file]
        set head [$self cget -head]
        set tail [$self cget -tail]
        
        if {$file == ""} {
            error "Option -file cannot be empty"
        }
        
        tabs::temporarilyUnmount $file {
            set filefh [open $file r]
            fconfigure $filefh -translation binary
        }
        
        set offset [tabs::getArchiveOffset $file]

        if {$head != ""} {
            if {[tabs::checkIfMounted $head]} {
                error "$head is currently mounted; cannot write"
            }
            set fh [open $head w]
            fconfigure $fh -translation binary
            if {$offset > 0} {
                seek $filefh 0
                fcopy $filefh $fh -size $offset
            }
            close $fh
        }

        if {$tail != ""} {
            if {[tabs::checkIfMounted $tail]} {
                error "$tail is currently mounted; cannot write"
            }
            set fh [open $tail w]
            fconfigure $fh -translation binary
            seek $filefh $offset
            fcopy $filefh $fh
            close $fh
        }
        
        close $filefh
    }

    method gethelp {} {
        return {
            -file {File to split}
            -head {File to write head as; this is the part before archive}
            -tail {File to write tail as; this is the archive part}
        }
    }
}

package provide tabs::job::split 1.0
