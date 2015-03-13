package require snit
package require tabs::win32mod
package require tabs::vfshandler

namespace eval tabs {}

snit::type tabs::job::wrap {
    component copyjob
    
    option -manager

    option -copyjob -default ""
    option -binary -default ""
    option -fileinfo -default ""
    option -icons -default [list]
    option -executionlevel -default ""
    option -starkit -default false -type snit::boolean
    option -driver -default ""
    option -driveroptions -default {}

    delegate option * to copyjob
    
    constructor {args} {
        install copyjob using tabs::createjob copy
        $copyjob configure -internal 1
        $self configurelist $args
    }

    method label {} {
        return "wrap [$self cget -output]"
    }

    method inputs {} {
        return [$copyjob inputs]
    }

    method outputs {} {
        return [list [$self cget -output]]
    }

    method execute {} {
	$copyjob configure -manager [$self cget -manager] -debug [$self cget -debug]
        set out [$self cget -output]
        set drv [$self cget -driver]
	set binary [$self cget -binary]
	
	if {$drv == ""} {
	    if {$binary != ""} {
		tabs::temporarilyUnmount $binary {
		    set drv [tabs::getDriver $binary]
		}
	    }  else  {
		error "Option -driver not specified"
	    }
	}

	[$self cget -manager] Debuglog 4 "Driver for creating binaries: $drv"

        tabs::loadDriver $drv

        if {[$self cget -starkit]} {
            set fh [open $out w]
            fconfigure $fh -translation binary
            puts $fh {#!/bin/sh}
            puts $fh "# \\"
            puts $fh {exec tclsh "$0" ${1+"$@"}}
            puts $fh "package require starkit"
            if {$drv == "mk4"} {
                puts $fh "starkit::header $drv -readonly"
            }  else  {
                puts $fh "starkit::header $drv"
            }
            puts $fh "\u001a"
            close $fh
        }  else  {
            if {$binary != ""} {
		# TODO: read in chunks to properly handle large binaries

		tabs::temporarilyUnmount $binary {
		    set fh [open $binary r]
		}
		
                fconfigure $fh -translation binary
                set filedata [read $fh]
                close $fh

                set origicondata ""
		set kitIcoShouldUnmount 0
                if {[catch {
		    # only mount if not currently mounted
		    if {![tabs::checkIfMounted $binary]} {
                        if {[catch {
			    set kitIcoUnmount [tabs::vfsMount $drv $binary 0 {}]
                        } err]} {
                            # TODO: log error for debugging
                        }
			set kitIcoShouldUnmount 1
		    }
                    set g [glob -nocomplain -directory $binary *kit.ico]
                    if {[llength $g] == 1} {
                        set fh [open [lindex $g 0] r]
                        fconfigure $fh -translation binary
                        set origicondata [read $fh]
                        close $fh
                    }
                } error]} {
		    [$self cget -manager] Printlog 2 "Unable to find icon: $error"
                }
		
		if {$kitIcoShouldUnmount} {
		    if {[catch {
			tabs::vfsUnmount $drv $binary $kitIcoUnmount 0
		    } err]} {
                        # TODO: log error for debugging; perhaps exit as error
                    }
		}
                set filedata [tabs::applyWin32Icons $filedata $origicondata [$self cget -icons] [$self cget -manager]]
                switch -- [$self cget -executionlevel] {
		    requireAdministrator {
			regsub "<requestedExecutionLevel level=\"......................uiAccess" $filedata \
                           "<requestedExecutionLevel level=\"requireAdministrator\" uiAccess" filedata
		    }
		    asInvoker {
			regsub "<requestedExecutionLevel level=\"......................uiAccess" $filedata \
                           "<requestedExecutionLevel level=\"asInvoker\"            uiAccess" filedata
		    }
		    "" {}
		    default {
                        set msg "Invalid -executionlevel \"[$self cget -executionlevel]\": should be one of requireAdministrator or asInvoker"
                        error $msg $msg
		    }
		}
                set fh [open $out w]
                fconfigure $fh -translation binary
                puts -nonewline $fh $filedata
                close $fh

		tabs::setWin32fileinfo $out [$self cget -fileinfo]

                catch {file attributes $out -permissions 0755}
            }  else  {
                set fh [open $out w]
                fconfigure $fh -translation binary
                close $fh
            }
        }

	set mountData [tabs::vfsMount $drv $out 1 [$self cget -driveroptions]]

        if {[catch {
            $copyjob execute
        } error]} {
            set ei $::errorInfo
            set ec $::errorCode
            if {[catch {tabs::vfsUnmount $drv $out $mountData 1} error]} {
                [$self cget -manager] Debuglog 3 "Error unmounting after error: $error"
            }

            [$self cget -manager] Debuglog 5 "Error information:\n$ei"
            return -code error -errorinfo $ei -errorcode $ec $error
        }

	tabs::vfsUnmount $drv $out $mountData 0
    }
    method gethelp {} {
        set rc [concat [$copyjob gethelp] {
            -driver {VFS type to use - supports mk4, zip and cookfs}
            -driveroptions {Additional options to pass to VFS driver; type dependant}
            -binary {Runtime to use for standalone binaries}
            -starkit {Create a starkit header for sourcing in Tcl}
            -icons {List of *.ico files to use for replacing icons in runtime; only valid for win32 platform}
            -fileinfo {List of name-value for specifying resource information; only valid for win32 platform}
            -executionlevel {Set execution level for binary for Windows Vista, Windows 7, if possible; only valid for win32 platform}
            -output {Output file}
        }]
        return $rc
    }
    method gethelptext {} {
	#set rc [$copyjob gethelptext]
	set rc ""
	append rc "Where -fileinfo is one of: FileDescription, OriginalFilename, CompanyName, LegalCopyright, FileVersion, ProductName, ProductVersion or ProductVersionBinary." \n
	return $rc
    }
}

package provide tabs::job::wrap 1.0
