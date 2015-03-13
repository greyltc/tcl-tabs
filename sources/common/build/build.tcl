namespace eval tabs {}

package require cmdline

# the default, unable to overwrite it for now without "make" job
set tabs::loglevel 3
# TODO: move to app.tcl

proc tabs::printlog {level str} {
    variable loglevel
    if {$level <= $loglevel} {
        puts "[clock format [clock seconds] -format %H:%M:%S] \[$level\] $str"
    }
}
proc tabs::parseOptions {argvvar optvar} {
    variable loglevel
    global argv0
    upvar #0 $optvar opt $argvvar argv

    set options {
        {directory.arg        ""                "Directory to run build in"}
        {file.arg             "Tabsfile"        "Build process definition file"}
        {tags.arg             ""                "Tags to pass to jobs"}
        {loglevel.arg         3                 "Log / verbosity level"}
    }
    
    set argv0 "tabs"

    set usage ": make ?options? targets"

    array set opt [cmdline::getoptions argv $options $usage]
    set loglevel $opt(loglevel)

    if {[llength $argv] == 0} {
        error "Please supply at least one build target"
    }
}

proc tabs::addDirectoryToPath {dir} {
    lappend ::auto_path $dir
    catch {tcl::tm::add $dir}
}

proc tabs::initTabs {} {
    uplevel #0 {
	while {[llength $argv] > 0} {
	    switch -- [lindex $argv 0] {
		-help {
		    tabs::showUsage
		}
		-loglevel {
		    if {([llength $argv] < 2) || (![string is integer -strict [lindex $argv 1]])} {
			tabs::showUsage
		    }
		    set tabs::loglevel [lindex $argv 1]
		    set argv [lrange $argv 2 end]
		}
		-path {
		    if {[llength $argv] < 2} {
			tabs::showUsage
		    }
		    tabs::addDirectoryToPath [lindex $argv 1]
		    set argv [lrange $argv 2 end]
		}
		default {
		    break
		}
	    }
	}
	if {[lindex $argv 0] == "make"} {
	    set argv [lrange $argv 1 end]
	    tabs::initTabsUsingTabsfile
	}  else  {
	    tabs::initTabsUsingRunjob
	}
    }
}

proc tabs::showTypeHelp {type} {
    package require tabs::jobs
    package require tabs::job::${type}
    set obj [tabs::jobmanagertype %AUTO% $type]
    puts stderr "Job type $type options :"
    array set help [$obj gethelp]
    foreach c [lsort -index 0 [$obj configure]] {
        set param [lindex $c 0]
        set default [lindex $c 3]
        if {[info exists help($param)]} {
            puts stderr [format " %-28s%s" "$param value" \
                "$help($param) <$default>"]
        }
    }
    set helptext [$obj gethelptext]
    if {$helptext != ""} {
	puts stderr "\n$helptext"
    }
    puts stderr ""
}

proc tabs::showTypeHtmlHelp {type} {
    set htmlmap [list \n "<br />" "<" "&lt;" ">" "&gt;" "\"" "&quot;"]
    package require tabs::jobs
    package require tabs::job::${type}
    set obj [tabs::jobmanagertype %AUTO% $type]

    set html ""
    append html "<table class=\"jobOptionTable\">\n"
    append html "<tr>\n"
    append html "<th class=\"jobOptionTable jobOptionHeader\">Option</th>\n"
    append html "<th class=\"jobOptionTable jobOptionHeader\">Default value</th>\n"
    append html "<th class=\"jobOptionTable jobOptionHeader\">Description</th>\n"
    append html "</tr>\n"

    array set help [$obj gethelp]
    set i2 0
    foreach c [lsort -index 0 [$obj configure]] {
        set param [lindex $c 0]
        set default [lindex $c 3]
        if {[info exists help($param)]} {
	    if {$default == ""} {set default "&nbsp;"}
            append html "<tr>\n"
	    append html "<td class=\"jobOptionTable jobOptionParam jobOptionRow jobOptionRow$i2\">" \
		[string map $htmlmap $param] "</td>"
	    append html "<td class=\"jobOptionTable jobOptionDefault jobOptionRow jobOptionRow$i2\">" \
		[string map $htmlmap $default] "</td>"
	    append html "<td class=\"jobOptionTable jobOptionDescription jobOptionRow jobOptionRow$i2\">" \
		[string map $htmlmap $help($param)] "</td>"
	    append html "</tr>\n"
	    set i2 [expr {1 - $i2}]
        }
    }
    append html "</table>" \n "<br />"
    set helptext [$obj gethelptext]
    if {$helptext != ""} {
	append html "<br />" [string map [list \n "<br />"] $helptext]
    }
    puts $html
}

proc tabs::showAllTypesHelp {} {
    catch {package require dummy}
    foreach pkg [package names] {
        if {[regexp "^tabs::job::(.*)\$" $pkg - type]} {
            showTypeHelp $type
        }
    }
}

proc tabs::initTabsUsingRunjob {} {
    global argv

    package require tabs::jobs

    set type [lindex $argv 0]
    if {([llength $argv] == 0) || (([llength $argv] == 1) && ([lindex $argv 0] == "-help"))} {
        tabs::showUsage
    }  elseif {([llength $argv] == 2) && ([lindex $argv 1] == "-htmlhelp")} {
        tabs::showTypeHtmlHelp [lindex $argv 0]
    }  elseif {([llength $argv] == 2) && ([lindex $argv 1] == "-help")} {
        tabs::showTypeHelp [lindex $argv 0]
    }  elseif {[catch {
        eval [concat [list ::tabs::runjob] $argv]
    } error]} {
        puts stderr "Unable to run job: $error"
        exit 1
    }
    exit 0
}

proc tabs::showUsage {} {
    catch {
        uplevel #0 {
            set argv "-help"
            tabs::parseOptions argv opt
        }
    } error
    puts stderr "Using tabs with build definitions stored in Tabsfile:"
    puts stderr ""
    puts stderr $error
    puts stderr ""
    puts stderr "Using tabs without Tabsfile (quick mode):"
    puts stderr ""
    puts stderr "tabs : ?globaloptions? jobtype ?options? -- run a single job without Tabsfile"
    puts stderr ""
    puts stderr "Global options:"
    puts stderr " -path                  Add specified directory to Tcl path when loading job packages"
    puts stderr " -loglevel              Log level to use"
    puts stderr ""
    puts stderr "Available job types:"
    puts stderr ""
    tabs::showAllTypesHelp

    exit 1
}

proc tabs::initTabsUsingTabsfile {} {
    variable tabsfile
    uplevel #0 {
        if {[catch {
            tabs::parseOptions argv opt
        } error]} {
            tabs::showUsage
        }

        package require tabs::jobs
        package require tabs::target

        namespace import ::tabs::*
        
        if {[catch {
            if {$opt(directory) != ""} {
                cd $opt(directory)
            }
        } error]} {
            puts stderr "Unable to change directory to \"$opt(directory)\": $error"
            exit 1
        }

        if {![file exists $opt(file)]} {
            puts stderr "Unable to build: \"$opt(file)\" does not exist."
            exit 1
        }

        set tabsfile $opt(file)
        if {[catch {
            source $tabsfile
        } error]} {
            set error [join [lrange [split $::errorInfo \n] 0 end-2] \n]
            puts stderr "Unable to read \"$opt(file)\": $error"
            exit 1
        }

        foreach target $argv {
            ::tabs::printlog 2 "Building $target"
            ::tabs::target::$target execute
        }
        
        ::tabs::printlog 2 "Build complete"
    }
}

package provide tabs::build 1.0
