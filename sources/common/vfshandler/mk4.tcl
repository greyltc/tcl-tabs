namespace eval tabs {}
namespace eval tabs::vfs {}
namespace eval tabs::vfs::mk4 {}

proc tabs::vfs::mk4::getArchiveOffset {filename} {
    set fh [open $filename r]
    fconfigure $fh -translation binary
    seek $fh -16 end
    binary scan [read $fh 16] IIII a b c d
    close $fh

    if {($c >> 24) != -128} {
        error "Not an mk4vfs file"
    }
    set end [file size $filename]
    if {($a & 0xffffffff) == 0x80000000} {
        return [expr {$end - 16 - $b}]
    } else {
        error "File in commit-progress state"
    }
}

proc tabs::vfs::mk4::vfsMount {filename writable options} {
    if {(!$writable) && ([lsearch -exact $options "-readonly"] < 0)} {
        lappend options -readonly
    }

    set cmd [list vfs::mk4::Mount $filename $filename]
    set cmd [concat $cmd $options]

    eval $cmd
}

proc tabs::vfs::mk4::vfsUnmount {filename data iserror} {
    vfs::unmount $filename
}

package provide tabs::vfshandler::mk4 1.0