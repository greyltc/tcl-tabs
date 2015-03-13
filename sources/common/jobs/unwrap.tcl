package require snit
package require fileutil
package require tabs::vfshandler

namespace eval tabs {}

snit::type tabs::job::unwrap {
    component copyjob
    
    option -manager

    option -file -default ""
    option -output -default ""
    
    delegate option -excludefiles to copyjob
    delegate option -excludedirectories to copyjob
    
    constructor {args} {
        install copyjob using tabs::createjob copy
        $copyjob configure -internal 1
        $self configurelist $args
    }
    
    method label {} {
        return "unwrap [$self cget -file]"
    }

    method uptodate {} {
        # TODO: copy behavior from wrap
        return 0
    }

    method execute {} {
        set file [$self cget -file]
        set output [$self cget -output]
        if {($output == "") || ($output == $file)} {
            set output $file.vfs
        }

        tabs::temporarilyUnmount $file {
            set drv [tabs::getDriver $file]
            set offset [tabs::getArchiveOffset $file]
            if {$offset > 0} {
                set sfh [open $file r]
                fconfigure $sfh -translation binary
            }
        }
        tabs::loadDriver $drv

        if {[tabs::checkIfMounted $output]} {
            error "$output is currently mounted - unable to unwrap"
        }

        if {![tabs::checkIfMounted $file]} {
            set oldMountData [tabs::vfsMount $drv $file 0 {}]
            set unmountFile 1
        }  else  {
            set unmountFile 0
        }

        $copyjob configure -output $output -copy [list \
            [list [tabs::mapForGlob $file]/*] \
            ]
        $copyjob execute

        if {$unmountFile} {
            tabs::vfsUnmount $drv $file $oldMountData 0
        }
    }  

    method gethelp {} {
        set rc [concat [$copyjob gethelp] {
            -file {File to unwrap}
            -output {File to write to; defaults to same as -file with .vfs appended if not specified}
        }]
    }
}

package provide tabs::job::unwrap 1.0
