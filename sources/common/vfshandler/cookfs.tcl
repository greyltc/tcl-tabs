namespace eval tabs {}
namespace eval tabs::vfs {}
namespace eval tabs::vfs::cookfs {}

proc tabs::vfs::cookfs::getArchiveOffset {filename} {
    tabs::loadDriver cookfs
    set p [cookfs::pages -readonly $filename]
    set offset [$p dataoffset]
    $p delete
    return $offset
}

proc tabs::vfs::cookfs::vfsMount {filename writable options} {
    if {!$writable} {
        lappend options -readonly
    }
    # cookfs version 1.3 and up supports -nodirectorymtime flag
    if {![catch {package require vfs::cookfs 1.3}]} {
        lappend options -nodirectorymtime
    }

    set cmd [list vfs::cookfs::Mount $filename $filename]
    set cmd [concat $cmd $options]

    eval $cmd
}

proc tabs::vfs::cookfs::vfsUnmount {filename data iserror} {
    vfs::unmount $filename
}


package provide tabs::vfshandler::cookfs 1.0
