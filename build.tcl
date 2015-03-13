#!/usr/bin/env tabs-cli
cd [file dirname [info script]]

lappend auto_path sources/common libraries

package require tabs::jobs
package require tabs::build

set tabs::loglevel 5

catch {
    file mkdir OUT
}

catch {
    vfs::mk4::Unmount exe [info nameofexe]
}

foreach {driver options binary dir output} {
#    mk4 "" "" cli tabs-cli.tcl
    zip "" "" cli tabs-cli-zip.tcl
    cookfs "" "" cli tabs-cli-cfs.tcl
#    cookfs "-compression bz2" "" cli tabs-cli-cfs-bz2.tcl
} {
    if {$binary == ""} {
        set starkit true
    }  else  {
        set starkit false
    }

    if {[catch {
        tabs::runjob wrap \
            -fail false \
            -binary $binary \
            -starkit $starkit \
            -output OUT/$output \
            -driver $driver -driveroptions $options \
            -copy [list \
                [list sources/main.tcl main.tcl] \
                [list libraries lib] \
                [list sources/common lib] \
                [list sources/$dir lib] \
                ]
    } error]} {
        puts "FAILED: $error"
    }
}

exit 0
