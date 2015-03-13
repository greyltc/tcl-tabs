package require snit
package require fileutil
package require tabs::vfshandler

namespace eval tabs {}

snit::type tabs::job::copy {
    option -manager

    option -excludefiles -default [list core]
    option -excludedirectories -default [list CVS .svn]
    option -output -default ""
    option -copy -default [list]
    option -packages -default [list]
    
    variable copylist [list]
    
    constructor {args} {
        $self configurelist $args
    }
    
    method label {} {
        return "copy to [$self cget -output]"
    }

    method inputs {} {
        set rc [list]
        foreach {in out} [$self Getinout true] {
            lappend rc $in
        }
        set rc [concat $rc [$self cget -packages]]
        return $rc
    }

    method copy {args} {
        if {([llength $args] % 2) == 1} {
            return -code error ""
        }
        foreach {in out} $args {
            lappend copylist [list $in $out]
        }
    }
    
    method Matchpatterns {patterns name} {
        foreach pattern $patterns {
            if {[string match $pattern $name]} {
                return true
            }
        }
        return false
    }

    method Listallfiles {pathlist} {
        set rc [list]
        foreach path $pathlist {
            file stat $path st
            set ok true
            if {$st(type) == "directory"} {
                if {![$self Matchpatterns [$self cget -excludedirectories] [file tail $path]]} {
                    set rc [concat $rc [$self Listallfiles \
                        [glob -directory $path -nocomplain *]]]
                }
            }  else  {
                if {![$self Matchpatterns [$self cget -excludefiles] [file tail $path]]} {
                    lappend rc $path
                }
            }
        }
        return $rc
    }

    method Getinout {all} {
        set pkgcopylist [list]
        foreach package [$self cget -packages] {
            lappend pkgcopylist [list $package .]
        }

        set rc [list]
        set inoutcopylist [list]
        foreach inout [$self cget -copy] {
	    foreach in [lsort [glob [lindex $inout 0]]] {
		if {[llength $inout] > 1} {
		    set out [lindex $inout 1]
		}  else  {
		    set out [file tail $in]
		}
	        lappend inoutcopylist [list $in $out]
	    }
        }
        foreach inout [concat $pkgcopylist $copylist $inoutcopylist] {
            set in [lindex $inout 0]
            set out [lindex $inout 1]
            if {$all} {
                foreach file [$self Listallfiles [list $in]] {
                    set fout [fileutil::stripPath $in $file]
                    if {$fout == "."} {
                        set fout $out
                    }  else  {
                        set fout [file join $out $fout]
                    }
                    lappend rc $file $fout
                }
            }  else  {
                lappend rc $in $out
            }
        }
        return $rc
    }

    method execute {} {
        if {[catch {
	    set unmountlist [list]
	    foreach package [$self cget -packages] {
		if {![tabs::checkIfMounted $package]} {
		    set drv [tabs::getDriver $package]
		    tabs::loadDriver $drv
		    lappend unmountlist $drv $package \
                        [tabs::vfsMount $drv $package 0 {}]
		}
	    }

            set list [$self Getinout true]
            [$self cget -manager] Debuglog 5 "Getinout: [llength $list] elements"

            set outdir [$self cget -output]

            foreach {in out} $list {
                set outpath [file join $outdir $out]
                [$self cget -manager] Debuglog 5 "Copying '$in' as '$outpath'"
                set dirname [file dirname $outpath]
                if {![info exists created($dirname)]} {
                    set created($dirname) 1
                    $self Makedirectory $outdir $out
                }

                # TODO: compile/strip comments
                file copy -force $in $outpath
            }
        } error]} {
            set ei $::errorInfo
            set ec $::errorCode
            [$self cget -manager] Printlog 1 "Error: $error"
            [$self cget -manager] Debuglog 5 "Error information:\n$ei"

	    foreach {drv package data} $unmountlist {
		tabs::vfsUnmount $drv $package $data 0
	    }
            return -code error -errorinfo $ei -errorcode $ec $error
        }

        foreach {drv package data} $unmountlist {
            tabs::vfsUnmount $drv $package $data 0
        }

        if {[info exists ec]} {
            return -code error -errorinfo $ei -errorcode $ec $error
        }
    }

    method Makedirectory {base path} {
        set oldpath $path
        set dirlist [list]
        # create a directory along with all parent directories; needed for mk4 wraps sometimes
        while {![string equal $oldpath [set path [file dirname $oldpath]]]} {
            set dirname [file join $base $path]
            if {![file exists $dirname]} {
                set dirlist [linsert $dirlist 0 $dirname]
            }  elseif  {[file type $dirname] != "directory"} {
                set err "[file dirname $path] is not a directory"
                return -code error -errorinfo $err $err
            }
            set oldpath $path
        }
        foreach dir $dirlist {
            file mkdir $dir
        }
    }

    method gethelp {} {
        return {
            -copy {List of files/directories to copy; specified as file/directory to copy or list specified as {source destination}}
            -packages {List of packages to include; specific to cookfs/cookit building}
            -output {Output directory}
            -excludefiles {List of filenames to exclude}
            -excludedirectories {List of directories to exclude from including}
        }
    }
}

package provide tabs::job::copy 1.0
