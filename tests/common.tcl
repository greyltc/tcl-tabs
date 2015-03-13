lappend auto_path [file join [pwd] sources/common]
lappend auto_path [file join [pwd] libraries]

proc writeBinary {filename contents} {
    set fh [open $filename w]
    fconfigure $fh -translation binary
    puts -nonewline $fh $contents
    close $fh
    return $filename
}

proc testRunjob {args} {
    set cmd [list exec [info nameofexecutable] [file join [pwd] OUT tabs-cli-zip.tcl]]
    set cmd [concat $cmd $args]
    lappend cmd ">@stdout" "2>@stderr"
    return [eval $cmd]
}
