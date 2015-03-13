# removed not to confuse tabs
package require snit
package require fileutil

namespace eval tabs {}

snit::type tabs::job::tclscript {
    option -manager

    option -inputs -default [list]
    option -outputs -default [list]
    option -interp -default false
    option -script -default [list]
    option -variables -default [list]

    constructor {args} {
        $self configurelist $args
    }
    method label {} {
        return "run Tcl script"
    }

    method inputs {} {
        return [$self cget -inputs]
    }

    method outputs {} {
        return [$self cget -outputs]
    }
    
    method execute {} {
        if {[$self cget -interp]} {
            set i [interp create]
            foreach {vn vv} [$self cget -variables] {
                $i eval [list set $vn $vv]
            }
            $i eval [$self cget -script]
            interp delete $i
        }  else  {
            foreach {vn vv} [$self cget -variables] {
                uplevel 1 [list set $vn $vv]
            }
            uplevel 1 [$self cget -script]
        }
    }

    method gethelp {} {
        return {
            -inputs {List of files that are input to the script; used to compare if script should be run}
            -outputs {List of files that are output to the script; used to compare if script should be run}
            -interp {Whether script should be run in dedicated interpreter}
            -variables {Set specified variables; specified as Tcl name-value pairs list}
            -script {Tcl script to run}
        }
    }
}

package provide tabs::job::tclscript 1.0
