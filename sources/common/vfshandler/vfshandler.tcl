package require tabs::vfshandler::cookfs
package require tabs::vfshandler::mk4
package require tabs::vfshandler::zip

namespace eval tabs {}

# TODO: handle mk4 and ZIP by reading tail of the file and figure out offset to beginning of archive
proc tabs::getDriver {filename} {
    tabs::temporarilyUnmount $filename {
        set fh [open $filename r]
    }
    fconfigure $fh -translation binary

    if {![catch {
        seek $fh 0 start
        set head [read $fh 2]
    }]} {
        if {$head == "JL"} {
            close $fh
            return "mk4"
        }  elseif {$head == "PK"} {
            close $fh
            return "zip"
        }
    }

    # check if it is cookfs archive by reading last 16 bytes
    if {![catch {
        seek $fh -16 end
        set tail [read $fh 16]
    }]} {
        if {[string range $tail 9 end] == "CFS0002"} {
            close $fh
            return "cookfs"
        }
    }
    close $fh

    # check if it is a zip archive; if not, fall back to mk4
    if {![catch {
        tabs::getArchiveOffset $filename zip
    }]} {
        return "zip"
    }  else  {
        return "mk4"
    }
}

proc tabs::checkIfMounted {binary} {
    # normalize using tclvfs if available, fall back to file normalize
    set binaryNormalized [file normalize $binary]
    catch {
        set binaryNormalized [vfs::filesystem fullynormalize $binary]
    }

    # temporarily unregister binary if needed
    set c [catch {
        vfs::filesystem info $binaryNormalized
    }]
    # if error was caught, binary is not mounted
    return [expr {$c?0:1}]
}

proc tabs::temporarilyUnmount {binary code} {
    # normalize using tclvfs if available, fall back to file normalize
    set binaryNormalized [file normalize $binary]
    catch {
        set binaryNormalized [vfs::filesystem fullynormalize $binary]
    }

    # temporarily unregister binary if needed
    if {![catch {
        set vfshandler [vfs::filesystem info $binaryNormalized]
    }]} {
        vfs::filesystem unmount $binaryNormalized
        # refresh parent listing since it causes issues on some tclkits otherwise
        catch {glob -directory [file dirname $binaryNormalized] -nocomplain *}
    }

    # run specified code
    set c [catch {uplevel 1 $code} result]
    set ei $::errorInfo
    set ec $::errorCode
    
    # re-register vfs handler if needed
    if {[info exists vfshandler]} {
        vfs::filesystem mount $binaryNormalized $vfshandler
        catch {glob -directory [file dirname $binaryNormalized] -nocomplain *}
    }

    # return error or success
    if {$c == 1} {
        error $result $ei $ec
    }  else  {
        return $result
    }
}

proc tabs::loadDriver {drv} {
    if {[catch {
        package require vfs::${drv}
    }]} {
        package require ${drv}vfs
    }
}

proc tabs::listAllFiles {from {prefix ""}} {
    set rc [list]
    foreach g [glob -directory $from -nocomplain *] {
        set pg [file join $prefix [file tail $g]]

        file lstat $g stat

        if {$stat(type) == "directory"} {
            set rc [concat $rc [listAllFiles $g $pg]]
        }  elseif  {$stat(type) == "file"} {
            lappend rc $pg
        }
    }
    return $rc
}

proc tabs::getArchiveOffset {filename {driver ""}} {
    tabs::temporarilyUnmount $filename {
        if {$driver == ""} {
            set driver [getDriver $filename]
        }
        set offset [tabs::vfs::${driver}::getArchiveOffset $filename]
    }
    return $offset
}

proc tabs::mapForGlob {string} {
    return [string map \
        [list "\[" "\\\[" "*" "\\*" "?" "\\?"] \
        $string]
}

proc tabs::vfsMount {driver filename writable options} {
    return [tabs::vfs::${driver}::vfsMount $filename $writable $options]
}

proc tabs::vfsUnmount {driver filename data {iserror 0}} {
    tabs::vfs::${driver}::vfsUnmount $filename $data $iserror
}

package provide tabs::vfshandler 1.0
