# ZIP file constructor

package provide zipper 0.11

namespace eval zipper {
  namespace export initialize addentry finalize

  namespace eval v {
    variable fd
    variable toc
  }

  # WK: helper functions to use zlib or alternate libraries, depending on what is available
  proc zlibcrc32 {contents var} {
    upvar $var crc32
    if {![catch {zlib crc32 $contents} rc]} {
      set crc32 $rc
      return 1
    }  elseif {![catch {package require crc32 ; crc::crc32 -format %d $contents} rc]} {
      set crc32 $rc
      return 1
    }  else  {
      set crc32 0
      return 0
    }
  }

  proc zlibdeflate {contents} {
    if {![catch {zlib deflate $contents} rc]} {
      return $rc
    }  elseif {![catch {package require vfs ; vfs::zip -mode compress -nowrap 1 $contents} rc]} {
      return $rc
    }  else  {
      error "Compression not available"
    }
  }
 
  proc initialize {fd} {
    set v::fd $fd
    set v::toc {}
    fconfigure $fd -translation binary -encoding binary
  }

  proc emit {s} {
    puts -nonewline $v::fd $s
  }

  proc dostime {sec} {
    set f [clock format $sec -format {%Y %m %d %H %M %S} -gmt 1]
    regsub -all { 0(\d)} $f { \1} f
    foreach {Y M D h m s} $f break
    set date [expr {(($Y-1980)<<9) | ($M<<5) | $D}]
    set time [expr {($h<<11) | ($m<<5) | ($s>>1)}]
    return [list $date $time]
  }

  proc adddirentry {name {date ""} {force 0}} {
    if {$date == ""} { set date [clock seconds] }
    # remove trailing slashes and add new one
    set name "[string trimright $name /]/"
    foreach {date time} [dostime $date] break
    set flag 2
    set type 0
    set crc 0
    set csize 0
    set fsize 0
    set fnlen [string length $name]

    lappend v::toc "[binary format a2c6ssssiiiss4ii PK {1 2 20 0 20 0} \
    			$flag $type $time $date $crc $csize $fsize $fnlen \
			{0 0 0 0} 128 [tell $v::fd]]$name"
    emit [binary format a2c4ssssiiiss PK {3 4 20 0} \
    		$flag $type $time $date $crc $csize $fsize $fnlen 0]
    emit $name

  }
  proc addentry {name contents {date ""} {force 0} {compress 1}} {
    if {$date == ""} { set date [clock seconds] }
    foreach {date time} [dostime $date] break
    set flag 0
    set type 0 ;# stored
    set fsize [string length $contents]
    set csize $fsize
    set fnlen [string length $name]

    if {$force > 0 && $force != [string length $contents]} {
      set csize $fsize
      set fsize $force
      set type 8 ;# if we're passing in compressed data, it's deflated
    }

    if {![zlibcrc32 $contents crc]} {
      set crc 0
    } elseif {$type == 0} {
      if {$compress} {
        set cdata [zlibdeflate $contents]
        if {[string length $cdata] < [string length $contents]} {
	  set contents $cdata
	  set csize [string length $cdata]
	  set type 8 ;# deflate
	}
      }
    }

    lappend v::toc "[binary format a2c6ssssiiiss4ii PK {1 2 20 0 20 0} \
    			$flag $type $time $date $crc $csize $fsize $fnlen \
			{0 0 0 0} 128 [tell $v::fd]]$name"

    emit [binary format a2c4ssssiiiss PK {3 4 20 0} \
    		$flag $type $time $date $crc $csize $fsize $fnlen 0]
    emit $name
    emit $contents
  }

  proc finalize {} {
    set pos [tell $v::fd]

    set ntoc [llength $v::toc]
    foreach x $v::toc { emit $x }
    set v::toc {}

    set len [expr {[tell $v::fd] - $pos}]

    emit [binary format a2c2ssssiis PK {5 6} 0 0 $ntoc $ntoc $len $pos 0]

    return $v::fd
  }

  proc wrapfile {filename directory} {
    set fd [open $filename w]
    close [wrap $fd $directory]
  }

  proc wrap {fd directory} {
    package require fileutil
    set directory [file normalize $directory]
    initialize $fd
    foreach find [lsort -unique [fileutil::find $directory]] {
      puts "Copying $find"
      if {[file type $find] == "file"} {
        addentry [fileutil::stripPath $directory $find] [fileutil::cat -translation binary $find]
      }
    }
    return [finalize]
  }
}

