package require snit
package require fileutil
package require tabs::vfshandler

namespace eval tabs {}

snit::type tabs::job::repack {
    component copyjob
    
    option -manager

    option -file -default ""
    option -output -default ""
    option -driver -default ""
    option -driveroptions -default ""
    
    delegate option -excludefiles to copyjob
    delegate option -excludedirectories to copyjob
    
    constructor {args} {
        install copyjob using tabs::createjob copy
        $copyjob configure -internal 1
        $self configurelist $args
    }
    
    method label {} {
        return "Repack [$self cget -file]"
    }

    method uptodate {} {
        set file [$self cget -file]
        set output [$self cget -output]
        if {($output == "") || ($output == $file)} {
            return 0
        }  else  {
            if {![file exists $output]} {
                return 0
            }  else  {
                return [expr {[file mtime $output] >= [file mtime $file]}]
            }
        }
    }

    method execute {} {
        set file [$self cget -file]
        set output [$self cget -output]
        set outdriver [$self cget -driver]
        if {($output == "") || ($output == $file)} {
            set tempoutput $file.tmp[pid]
            set output $file
        }  else  {
            set tempoutput $output
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
        if {$outdriver != ""} {
            tabs::loadDriver $outdriver
        }  else  {
            set outdriver $drv
        }

        if {[tabs::checkIfMounted $output] || [tabs::checkIfMounted $tempoutput]} {
            error "$output is currently mounted - unable to repack"
        }

        if {![tabs::checkIfMounted $file]} {
            set oldMountData [tabs::vfsMount $drv $file 0 {}]
            set unmountFile 1
        }  else  {
            set unmountFile 0
        }

        set dfh [open $tempoutput w]
        fconfigure $dfh -translation binary
        if {$offset > 0} {
            fcopy $sfh $dfh -size $offset
            close $sfh
        }
        close $dfh

        set mountData [tabs::vfsMount $outdriver $tempoutput 1 [$self cget -driveroptions]]

        $copyjob configure -output $tempoutput -copy [list \
            [list [tabs::mapForGlob $file]/*] \
            ]
        $copyjob execute

        if {$unmountFile} {
            tabs::vfsUnmount $drv $file $oldMountData 0
        }
        tabs::vfsUnmount $outdriver $tempoutput $mountData 0

        if {$tempoutput != $output} {
            catch {file delete -force $output}
            file rename $tempoutput $output
        }
    }  

    method gethelp {} {
        set rc [concat [$copyjob gethelp] {
            -file {File to repack}
            -output {File to write to; defaults to same as -file if not specified}
            -driver {VFS type to use - supports mk4, zip and cookfs; defaults to input driver if not specified}
            -driveroptions {Additional options to pass to VFS driver; type dependant}
        }]
    }
}

package provide tabs::job::repack 1.0
