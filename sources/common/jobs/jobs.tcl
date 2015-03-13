namespace eval tabs {}

package require snit

proc tabs::createjob {type args} {
    package require tabs::job::${type}

    set obj [eval [concat [list tabs::jobmanagertype %AUTO% $type] $args]]
}

proc tabs::runjob {type args} {
    package require tabs::job::${type}

    if {[catch {
	set obj [eval [concat [list tabs::jobmanagertype %AUTO% $type] $args]]
    } error]} {
	tabs::printlog 1 "Unable to create job: $error"
	return
    }
    if {[catch {
	uplevel 1 [list $obj execute]
    } error]} {
	set ei $::errorInfo
	if {[$obj cget -debug]} {
	    tabs::printlog 1 "[$obj label] Unable to execute job:\n$ei"
	}  else  {
	    tabs::printlog 1 "[$obj label] Unable to execute job: $error"
	}
        if {[$obj cget -fail]} {
            error $error $error TABSERROR
        }
    }
}

snit::type tabs::jobmanagertype {
    delegate option * to job
    option -skiptags -default ""
    option -label -default ""
    option -internal -default false
    option -checkuptodate -default false
    option -debug -default false
    option -fail -default true
    variable jobtype
    
    constructor {_jobtype args} {
        set jobtype ${_jobtype}
        install job using ::tabs::job::$jobtype %AUTO% -manager $self 
        set args [$self Parseargs $args]
        $self configurelist $args
    }
    
    variable jobdepends

    method Parseargs {argv} {
        if {![catch {
            $job optionmap
        } optionmap]} {
	    foreach opt $optionmap {
		if {([llength $argv] == 0) || ([string index [lindex $argv 0] 0] == "-")} {
		    break
		}
		if {([llength $argv] > 0) && ([string index [lindex $argv 0] 0] != "-")} {
		    $job configure $opt 
		}
	    }
        }
        return $argv
    }

    method label {} {
        set label [$self cget -label]
        if {$label == ""} {
            set jobmethods [$job info methods]
            if {[lsearch -exact $jobmethods "label"] >= 0} {
                set label [$job label]
            }
        }
        if {$label == ""} {
            set label "Job $self"
        }
        return $label
    }

    method Skiptags {} {
        return false
    }

    method Printlog {level str} {
        if {![$self cget -internal]} {
            tabs::printlog $level "\[[$self label]\] $str"
        }
    }
    
    method Debuglog {level str} {
	if {[$self cget -debug]} {
	    tabs::printlog $level "\[[$self label]\] $str"
	}
    }

    method Listallfiles {pathlist} {
        set rc [list]
        foreach path $pathlist {
            if {[catch {
                file stat $path st
            } error]} {
                lappend rc $path
                continue
            }
            if {$st(type) == "directory"} {
                set rc [concat $rc [$self Listallfiles \
                    [glob -directory $path -nocomplain *]]]
            }  else  {
                lappend rc $path
            }
        }
        return $rc
    }

    method Checkuptodate {inputs outputs} {
        set maxinput 0
        set maxoutput 0
        
        foreach path $inputs {
            file stat $path st
            if {$maxinput < $st(mtime)} {
                set maxinput $st(mtime)
            }
        }
        foreach path $outputs {
            if {[catch {
                file stat $path st
            }]} {
                return false
            }
            if {$maxoutput < $st(mtime)} {
                set maxoutput $st(mtime)
            }
        }
        $self Printlog 5 "Output-input: [expr {$maxoutput - $maxinput}]"
        if {$maxoutput < $maxinput} {
            $self Printlog 4 "Outputs of job are out of date - input: [clock format $maxinput -format {%Y-%m-%d %H:%M:%S}]; output: [clock format $maxoutput -format {%Y-%m-%d %H:%M:%S}]"
            return false
        }  else  {
            $self Printlog 4 "Job is up to date - input: [clock format $maxinput -format {%Y-%m-%d %H:%M:%S}]; output: [clock format $maxoutput -format {%Y-%m-%d %H:%M:%S}]"
            return true
        }
    }
    
    method Refreshjobdepends {} {
        # only refresh once
        if {![info exists jobdepends(DONE)]} {
            set jobmethods [$job info methods]
            
            if {[lsearch -exact $jobmethods "inputs"] >= 0} {
                set jobdepends(inputs) [$job inputs]
                 
            }  else  {
                set jobdepends(inputs) [list]
            }
            if {[lsearch -exact $jobmethods "outputs"] >= 0} {
                set jobdepends(outputs) [$job outputs]
            }  else  {
                set jobdepends(outputs) [list]
            }
            
            if {[lsearch -exact $jobmethods "uptodate"] >= 0} {
                set jobdepends(uptodate) [$job uptodate]
            }  else  {
                if {([llength $jobdepends(inputs)] > 0)  
                    && ([llength $jobdepends(outputs)] > 0)} {
                    set jobdepends(allinputs) \
                        [$self Listallfiles $jobdepends(inputs)]
                    set jobdepends(alloutputs) \
                        [$self Listallfiles $jobdepends(outputs)]
                    
                    set jobdepends(uptodate) [$self Checkuptodate \
                        $jobdepends(allinputs) \
                         $jobdepends(alloutputs)]
                }  else  {
                    $self Printlog 4 "Job is not up to date - inputs or outputs list is empty"
                    set jobdepends(uptodate) false
                }
                
            }

            set jobdepends(DONE) true
        }
    }
    
    method inputs {} {
        $self Refreshjobdepends
        return $jobdepends(inputs)
    }

    method outputs {} {
        $self Refreshjobdepends
        return $jobdepends(outputs)
    }

    method uptodate {} {
        $self Refreshjobdepends
        return $jobdepends(uptodate)
    }

    method execute {} {
        if {[$self Skiptags]} {
            $self Printlog 5 "Skipping execution of job - tags mismatch"
        }  else  {
            if {[$self cget -checkuptodate]} {
                set run [expr {[$self uptodate] ? 0 : 1}]
            }  else  {
                set run 1
            }
            if {$run} {
                $self Printlog 5 "Executing job"
                uplevel 1 [list $job execute]
            }  else  {
                $self Printlog 5 "Skipping execution of job"
            }
            
        }
    }

    method gethelp {} {
	if {[lsearch -exact [$job info methods] "gethelp"] >= 0} {
	    set rc [$job gethelp]
	}  else  {
	    set rc ""
	}
        set rc [concat $rc {
            -skiptags {Currently unused}
	    -checkuptodate {Whether check if job is up to date should be done; otherwise job is always run}
	    -fail {Fail entire build if job fails}
        }]
        return $rc
    }
    method gethelptext {} {
	if {[lsearch -exact [$job info methods] "gethelptext"] >= 0} {
	    set rc [$job gethelptext]
	}  else  {
	    set rc ""
	}
	return $rc
    }
}

namespace eval tabs {
    namespace export createjob runjob
}

package provide tabs::jobs 1.0
