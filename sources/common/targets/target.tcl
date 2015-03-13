namespace eval tabs {}
namespace eval tabs::target {}

package require snit

proc tabs::target {name args} {
    set obj ::tabs::target::$name
    eval [concat [list ::tabs::targettype $obj] $args]
    return $obj
}

snit::type tabs::targettype {
    option -body -default ""

    option -depends -default [list]

    constructor {args} {
        $self configurelist $args
    }
    
    variable inprogress 0

    method execute {} {
        # to avoid infinite dependency loops
        if {$inprogress} {
            return
        }
        set inprogress 1
        if {[catch {
            foreach dependency [$self cget -depends] {
                set dobj ::tabs::target::$dependency
                tabs::printlog 2 "Building $dependency"
                $dobj execute
            }
            
            uplevel 1 [$self cget -body]
        } error]} {
            set ei $::errorInfo
            set ec $::errorCode
            set inprogress 0
            return -code error -errorinfo $ei -errorcode $ec $error
        }
        set inprogress 0
    }
}

namespace eval tabs {
    namespace export target
}

package provide tabs::target 1.0
