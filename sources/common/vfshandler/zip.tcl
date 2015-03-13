namespace eval tabs {}
namespace eval tabs::vfs {}
namespace eval tabs::vfs::zip {}

proc tabs::vfs::zip::getArchiveOffset {filename} {
    tabs::loadDriver zip
    set fh [::open $filename r]
    fconfigure $fh -translation binary
    ::zip::EndOfArchive $fh a
    close $fh
    return $a(base)
}

proc tabs::vfs::zip::vfsMount {filename writable options} {
    if {!$writable} {
        vfs::zip::Mount $filename $filename
        return [list]
    }  else  {
        set vfstempfile [::fileutil::tempfile tabstempfile]
        catch {file delete -force $vfstempfile}

        if {[catch {
            tabs::loadDriver mk4
            vfs::mk4::Mount $vfstempfile $vfstempfile
            set driver mk4
        }]} {
            tabs::loadDriver cookfs
            vfs::cookfs::Mount $vfstempfile $vfstempfile
            set driver cookfs
        }

        if {![catch {
            vfs::zip::Mount $filename $filename
        }]} {
            foreach g [glob -nocomplain -directory $filename -tails *] {
                file copy -force [file join $filename $g] [file join $vfstempfile $g]
            }
            vfs::unmount $filename
        }
        vfs::unmount $vfstempfile

        set fh [open $filename a+]
        vfs::${driver}::Mount $vfstempfile $filename
        return [list $fh $vfstempfile $options]
    }
}

proc tabs::vfs::zip::vfsUnmount {filename data iserror} {
    set fh [lindex $data 0]
    set vfstempfile [lindex $data 1]
    set options [lindex $data 2]

    if {$fh == ""} {
        # read only archive; simply unmount it
        vfs::unmount $filename
    }  else  {
        catch {unset zipopt}
        array set zipopt {-compress 1}
        array set zipopt $options

        if {!$iserror} {
            # if operation succeeded, copy all files
            package require zipper

            fconfigure $fh -translation binary
            zipper::initialize $fh

            foreach file [tabs::listAllFiles $filename] {
                set fullpath [file join $filename $file]
                file lstat $fullpath stat
                if {$stat(type) == "file"} {
                    zipper::addentry $file \
                        [fileutil::cat -translation binary $fullpath] \
                        [file mtime $fullpath] 0 $zipopt(-compress)
                }
            }

            # finalize ZIP archive
            close [zipper::finalize]
        }  else  {
            close $fh
        }
        vfs::unmount $filename
        if {$vfstempfile != ""} {
            catch {file delete -force $vfstempfile}
        }
    }
    
}

package provide tabs::vfshandler::zip 1.0
