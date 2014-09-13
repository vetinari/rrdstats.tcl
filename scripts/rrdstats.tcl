##########################################################################
#                                                                        #
# rrdstats.tcl - create channel stats graphics with Tobias Oetiker's     #
#                rrdtool                                                 #
#                ( http://people.ee.ethz.ch/~oetiker/webtools/rrdtool/ ) #
#                                                                        #
##########################################################################
#                                                                        #
# Author: Hanno Hecker <vetinari@ankh-morp.org>                          #
#                                                                        #
# Install:                                                               #
#        - Build and install the rrdtool. Maybe you have to call the     #
#          configure script with --with-tcllib=/path/to/your/tcl/lib     #
#          (that's the dir, where your tclConfig.sh resides) to build    #
#          the tclrrd.so (will be in the tcl subdir of the source if     #
#          the build was succesful). Copy the tcl/tclrrd.so to a dir     #
#          where the bot can find it and change the .conf                #
#        - Copy the .tcl files to the scripts/ directory of your bot     #
#          and the .conf file to your bot dir (probably ~/eggdrop/).     #
#        - read the changelog below, it contains hints how to configure  #
#        - Edit the config file to fit your settings (and maybe setup a  #
#          cronjob for scripts/mkrrdgraphs.tcl like the example in the   #
#          .conf).                                                       #
#        - verify that the alltools.tcl is loaded                        #
#        - maybe your alltools.tcl which ships with your eggdrop is also #
#          broken. Use the fix as stated in the Changes below...         #
#        - Add a line                                                    #
#             source scripts/rrdstats.tcl                                #
#          to your bots config and rehash... you will see some messages  #
#          which say that the .rrd files are created (this happens just  #
#          at the first start of this script).                           #
#        - You might want to create a HTML Page to show your stats :o)   #
#                                                                        #
#  At http://shell-tools.org/~eggdrop/ruhrpott.html you can see some     #
#  example stats.                                                        #
#                                                                        #
# Tested with: eggdrop 1.6.6, tcl 8.2 & tcl 8.3 and rrdtool 1.0.33       #
# Requires: alltools.tcl (maybe with a bugfix)                           #
#                                                                        #
#  ... if you have trouble loading and using the tcl rrd extension, find #
#  the lines (yes, there's more than 1 on all files...)                  #
# package require Rrd 1.0.13                                             #
#  and change them to match the similar line in the tcl/ifOctets.tcl     #
#  script from the rrdtool source dir.                                   #
#                                                                        #
##########################################################################
# Changelog:
#  0.1 - Date: 2001-11-20
#      - initial version
#      - keeps track of current users on channel and the maximum/minimum
#        users during the last 7 days (this should be enough, else the
#        rrd files grow too big and it takes too much time to draw the
#        graphs... maybe this is configurable one day :-))
#
#  0.2 - Date: 2001-11-21
#      - also counts voices and ops and lines/actions
#      - switched from hourly max/min settings to 15 minutes
#
#  0.3 - Date: 2001-11-22
#      - moved rrd_draw_graph to rrdstats-graph.tcl
#      - extra script (mkrrdgraphs.tcl) to create the graphs (this
#        script also sources the rrdstats.conf). This script can be
#        called from a cronjob or another external script which creates
#        other stats and does not block the eggdrop from doing it's job
#
#  0.4 - Date: 2001-11-24
#      - removed MIN/MAX from the .rrd files and added data for 31 days.
#      - added weekly and monthly graphs to mkrrdgraphs.tcl
#      - changed the "bind CTCP - ACTION" and "bind PUBM - *" to a
#        "bind RAW - PRIVMSG" ... CTCP should be stackable...
#      - line length (and length of actions of course) is recorded now, too
#        (avgerage of 5 minutes...)
#      - added number of words in lines and actions...
#      - configurable image type (PNG/GIF)
#      - length of data recording is now configurable (0 for a day, 1 for
#        one week and 2 for a month) ... longer times are probably not
#        useful: the users data for 1 month is 7.5 MB.
#      - added joins & parts/quits/kicks stats (average of 5 mins)
#
#  0.5 - Date: 2001-11-28
#      - added domain stats, a configurable number of domain masks (e.g.
#        *.t-dialin.net *.pppool.de *.de) can be given. This number CAN
#        NOT be changed... If there's a more specific domain within a
#        given toplevel domain, it has to be named _before_ the more
#        generic. Example:
#        to count all .aol.com users and all other .com you have to
#        set rrd_domains {
#            *.aol.com *.com
#        }
#      - hmm, the testip proc in alltools.tcl which ships with eggdrop 1.6.6
#        (at least, haven't looked in other versions) is broken...
#        the fix is to remove the ! at line 277, i.e. change
#            if {((![regexp \[^0-9\] $i]) || ([string length $i] > 3) || \
#        to
#            if {(([regexp \[^0-9\] $i]) || ([string length $i] > 3) || \
#        This is fixed in 1.6.7-CVS :-)
#      - changed the join/part statistics to show the absolute number instead
#        of the average of the five minute steps and set the line width to 2
#      - cleaned up scripts/rrdstats-graph.tcl ... now it's much shorter
#        and (hopefully *g*) more readable
#
# Thoughts/Wishlist/ToDo:
#      ? configurable if ops/voice are shown?
#        ... as a workaround set ops, users and voice to the same color ;-)
#      ? move the rrd file creation to an extra file?
#      ? nicer default colors :-)
#      o find more things to monitor on a channel, e.g.
#          ? number of users on chan who have a bot handle
#      ! documentation/install/...
#

########################################################################
###              nothing to change below these line                  ###
###           unless you really know what you are doing              ###
###          configuration is done in rrdstats.conf ....             ###
########################################################################
global alltools_loaded
if {!$alltools_loaded} {
    die "rrdstats.tcl: scripts/alltools.tcl is not loaded"
}
### get the settings:
source rrdstats.conf
### maybe load the tclrrd.so
global rrd_lib rrd_graph_update
if {$rrd_lib != ""} {
    load $rrd_lib
}
if {$rrd_graph_update} {
    source scripts/rrdstats-graph.tcl
}
package require Rrd 1.4.7

### ok, let's go
set rrd_version "0.5"

global rrd_file rrd_chans rrd_stats rrd_time rrd_domains
### create rrd files if not yet existent and initialize counters
foreach chan $rrd_chans {
    set rrd_linecounter($chan) 0
    set rrd_actioncounter($chan) 0
    set rrd_linelength($chan) 0
    set rrd_actionlength($chan) 0
    set rrd_linewords($chan) 0
    set rrd_actionwords($chan) 0
    set rrd_joincounter($chan) 0
    set rrd_partcounter($chan) 0
    set rrd_quitcounter($chan) 0
    set rrd_kickcounter($chan) 0
    set rrd_chanfile ""
    set chan [string range $chan 1 end]
    if {$rrd_stats(users)} {
        regsub -all -- "%chan" $rrd_file     $chan   rrd_chanfile
        regsub -all -- "%type" $rrd_chanfile "users" rrd_chanfile
        if {![file exists $rrd_chanfile]} {
            putlog "rrdstats: creating $rrd_chanfile ..."
            ### the max number of users in a channel is 8192...
            ### that should be enough
            switch -exact -- $rrd_time {
                0 { set len 1440   }
                1 { set len 10080  }
                2 { set len 312480 }
                default { set len 10080  }
            }
            Rrd::create $rrd_chanfile --step 60 \
                DS:numUsers:GAUGE:120:0:8192    \
                DS:numOps:GAUGE:120:0:8192      \
                DS:numVoice:GAUGE:120:0:8192    \
                RRA:AVERAGE:0.5:1:$len
        }
    }
    if {$rrd_stats(lines)} {
        regsub -all -- "%chan" $rrd_file     $chan   rrd_chanfile
        regsub -all -- "%type" $rrd_chanfile "lines" rrd_chanfile
        if {![file exists $rrd_chanfile]} {
            putlog "rrdstats: creating $rrd_chanfile ..."
            ### it's probably safe, to set the max number of
            ### lines/5 minutes in a channel to 8192
            switch -exact -- $rrd_time {
                0 { set len 288   }
                1 { set len 2016  }
                2 { set len 62496 }
                default { set len 2016 }
            }
            Rrd::create $rrd_chanfile --step 300 \
                DS:numLines:GAUGE:600:0:8192     \
                DS:numActions:GAUGE:600:0:8192   \
                DS:avgLineLength:GAUGE:600:0:255 \
                DS:avgActLength:GAUGE:600:0:255  \
                DS:avgLineWords:GAUGE:600:0:255  \
                DS:avgActWords:GAUGE:600:0:255   \
                RRA:AVERAGE:0.5:1:$len
        }
    }
    if {$rrd_stats(joins)} {
        regsub -all -- "%chan" $rrd_file     $chan   rrd_chanfile
        regsub -all -- "%type" $rrd_chanfile "joins" rrd_chanfile
        if {![file exists $rrd_chanfile]} {
            putlog "rrdstats: creating $rrd_chanfile ..."
            switch -exact -- $rrd_time {
                0 { set len 288   }
                1 { set len 2016  }
                2 { set len 62496 }
                default { set len 2016 }
            }
            Rrd::create $rrd_chanfile --step 300 \
                DS:numJoins:GAUGE:600:0:8192     \
                DS:numParts:GAUGE:600:-8192:0    \
                DS:numQuits:GAUGE:600:-8192:0    \
                DS:numKicks:GAUGE:600:-8192:0    \
                RRA:AVERAGE:0.5:1:$len
        }
    }
    if {$rrd_stats(domain)} {
        global rrd_binary
        regsub -all -- "%chan" $rrd_file     $chan   rrd_chanfile
        regsub -all -- "%type" $rrd_chanfile "domain" rrd_chanfile
        if {![file exists $rrd_chanfile]} {
            putlog "rrdstats: creating $rrd_chanfile ..."
            switch -exact -- $rrd_time {
                0 { set len 288   }
                1 { set len 2016  }
                2 { set len 62496 }
                default { set len 2016 }
            }
            set l [llength $rrd_domains]
            set doms [list]
            for {set i 1} {$i <= $l} {incr i} {
                lappend doms " DS:domain_${i}:GAUGE:600:0:4096"
            }
            set doms [join $doms " "]
            set rrd [open "|$rrd_binary -" w]
            puts $rrd "create $rrd_chanfile --step 300 \
                DS:domain_IP:GAUGE:600:0:4096    \
                DS:domain_other:GAUGE:600:0:4096 \
                $doms RRA:AVERAGE:0.5:1:$len"
            close $rrd
        }
    }
}

proc rrd_update {minute hour day month year} {
    global rrd_stats rrd_graph_update
    if {$rrd_stats(users)} {
        rrd_update_users
    }
    if {[string index $minute 0] == "0"} {
        set minute [string index $minute 1]
    }
    if {[expr $minute % 5] == 0} {
        if {$rrd_stats(lines)} { rrd_update_lines }
        if {$rrd_stats(joins)} { rrd_update_joins }
        if {$rrd_stats(domain)} { rrd_update_domain }
    }
    if {$rrd_graph_update} {
        if {[expr $minute % $rrd_graph_update] == 0} {
            foreach name [array names rrd_stats *] {
                if {$name == "ops"} { continue }
                if {$rrd_stats($name)} {
                    rrd_draw_graph $name
                }
            }
        }
    }
}

proc rrd_update_lines {} {
    global rrd_file rrd_chans rrd_linecounter rrd_actioncounter
    global rrd_linelength rrd_actionlength rrd_linewords rrd_actionwords
    foreach chan $rrd_chans {
        set file ""
        set stripchan [string range $chan 1 end]
        regsub -all -- "%chan" $rrd_file $stripchan file
        regsub -all -- "%type" $file     "lines"    file
        set lines   $rrd_linecounter($chan)
        set actions $rrd_actioncounter($chan)
        set avglinelen 0
        set avgactlen 0
        set avglinewords 0
        set avgactwords 0
        if {$lines} {
            set avglinelen [expr $rrd_linelength($chan) / "$lines.0"]
            set avglinewords [expr $rrd_linewords($chan) / "$lines.0"]
        }
        if {$actions} {
            set avgactlen [expr $rrd_actionlength($chan) / "$actions.0"]
            set avgactwords [expr $rrd_actionwords($chan) / "$actions.0"]
        }
        if {!($lines || $actions)} {
            if {![botonchan $chan]} {
                set lines   "U"
                set actions "U"
                set avglinelen "U"
                set avgactlen "U"
                set avglinewords "U"
                set avgactwords "U"
            }
        }
        Rrd::update $file \
           --template numLines:numActions:avgLineLength:avgActLength:avgLineWords:avgActWords \
           N:$lines:$actions:$avglinelen:$avgactlen:$avglinewords:$avgactwords
        # putlog "rrd_update(lines) N:$lines:$actions:$avglinelen:$avgactlen:$avglinewords:$avgactwords"
        set rrd_linecounter($chan) 0
        set rrd_actioncounter($chan) 0
        set rrd_linelength($chan) 0
        set rrd_actionlength($chan) 0
        set rrd_linewords($chan) 0
        set rrd_actionwords($chan) 0
    }
}

proc rrd_update_domain {} {
    global rrd_file rrd_chans rrd_domains
    foreach chan $rrd_chans {
        set file ""
        set stripchan [string range $chan 1 end]
        regsub -all -- "%chan" $rrd_file $stripchan file
        regsub -all -- "%type" $file     "domain"    file
        if {![botonchan $chan]} {
            set dom_cnt(%OTHER%) "U"
            set dom_cnt(%IP%)    "U"
            set vals "U:U:U"
        } else {
            set dom_cnt(%IP%) 0
            foreach name $rrd_domains {
                set dom_cnt($name) 0
            }
            set chan_list [chanlist $chan]
            foreach nick $chan_list {
                set domain [getchanhost $nick $chan]
                set domain [string range $domain [expr [string first "@" $domain] + 1] end]
                if {[testip $domain]} {
                    incr dom_cnt(%IP%)
                } else {
                    foreach dom $rrd_domains {
                        if {[string match -nocase $dom $domain]} {
                            incr dom_cnt($dom)
                            break
                        }
                    }
                }
            }
            set all [llength $chan_list]
            set found $dom_cnt(%IP%)
            foreach dom $rrd_domains {
                incr found $dom_cnt($dom)
            }
            set dom_cnt(%OTHER%) [expr $all - $found]
            set vals [list]
            foreach dom $rrd_domains {
                lappend vals $dom_cnt($dom)
            }
            set vals [join $vals ":"]
        }
        set doms [list]
        set l [llength $rrd_domains]
        for {set i 1} {$i <= $l} {incr i} {
            lappend doms "domain_$i"
        }
        Rrd::update $file --template [join $doms ":"]:domain_IP:domain_other \
           N:$vals:$dom_cnt(%IP%):$dom_cnt(%OTHER%)
        #putlog DOMAINS=N:$vals:$dom_cnt(%IP%):$dom_cnt(%OTHER%)
    }
}

proc rrd_update_joins {} {
    global rrd_file rrd_chans rrd_joincounter rrd_partcounter
    global rrd_quitcounter rrd_kickcounter
    foreach chan $rrd_chans {
        set file ""
        set stripchan [string range $chan 1 end]
        regsub -all -- "%chan" $rrd_file $stripchan file
        regsub -all -- "%type" $file     "joins"    file
        set joins   $rrd_joincounter($chan)
        set quits   [expr $rrd_quitcounter($chan) * -1]
        set parts   [expr $rrd_partcounter($chan) * -1]
        set kicks   [expr $rrd_kickcounter($chan) * -1]
        if {!($quits || $parts || $joins || $kicks)} {
            if {![botonchan $chan]} {
                set quits "U"
                set parts "U"
                set joins "U"
                set kicks "U"
            }
        }
        Rrd::update $file \
           --template numJoins:numParts:numQuits:numKicks \
           N:$joins:$parts:$quits:$kicks
        #putlog "rrd_update(joins) N:$joins:$parts:$quits:$kicks"
        set rrd_joincounter($chan) 0
        set rrd_partcounter($chan) 0
        set rrd_quitcounter($chan) 0
        set rrd_kickcounter($chan) 0
    }
}

proc rrd_update_users {} {
    global rrd_file rrd_chans
    foreach chan $rrd_chans {
        set stripchan [string range $chan 1 end]
        if {[botonchan $chan]} {
            set chan_list [chanlist $chan]
            set numUsers [llength $chan_list]
            set numVoice 0
            set numOps   0
            foreach user $chan_list {
                if {[isop $user $chan]} {
                    incr numOps
                } else {
                    incr numVoice [isvoice $user $chan]
                }
            }
        } else {
            set numUsers "U"
            set numOps   "U"
            set numVoice "U"
        }
        set file ""
        regsub -all -- "%chan" $rrd_file $stripchan file
        regsub -all -- "%type" $file     "users"    file
        Rrd::update $file --template numUsers:numOps:numVoice \
           N:$numUsers:$numOps:$numVoice
        # putlog "rrd_update(users) N:$numUsers:$numOps:$numVoice"
    }
}

proc rrd_joincount {nick uhost hand chan} {
    global rrd_joincounter
    if {[llength [array names rrd_joincounter $chan]] != 0} {
        incr rrd_joincounter($chan)
    }
}

proc rrd_partcount {nick uhost hand chan msg} {
    global rrd_partcounter
    if {[llength [array names rrd_partcounter $chan]] != 0} {
        incr rrd_partcounter($chan)
    }
}

proc rrd_quitcount {nick uhost hand chan reason} {
    global rrd_quitcounter
    if {[llength [array names rrd_quitcounter $chan]] != 0} {
        incr rrd_quitcounter($chan)
    }
}

proc rrd_kickcount {nick uhost hand chan target reason} {
    global rrd_kickcounter
    if {[llength [array names rrd_kickcounter $chan]] != 0} {
        incr rrd_kickcounter($chan)
    }
}

proc rrd_counter {from keyword txt} {
    global rrd_linecounter rrd_actioncounter rrd_linelength rrd_actionlength
    global rrd_linewords rrd_actionwords
    set words [split $txt]
    set chan  [string tolower [lindex $words 0]]
    if {[llength [array names rrd_linecounter $chan]] == 0} {
        return 0
    }
    set colon_pos [expr [string first ":" $txt] + 1]
    set txt [string range $txt $colon_pos end]
    if {([lindex $words 1] == ":\001ACTION") && \
            ([string index $txt end] == "\001")} {
        incr rrd_actioncounter($chan)
        incr rrd_actionlength($chan) [string length $txt]
        incr rrd_actionwords($chan) [expr [llength $words] - 1]
    } else {
        incr rrd_linecounter($chan)
        incr rrd_linelength($chan)  [string length $txt]
        incr rrd_linewords($chan) [expr [llength $words] -1]
    }
    return 0
}

catch { unbind time - "* * * * *" rrd_update }
catch { unbind raw  - PRIVMSG     rrd_counter }
catch { unbind join - *           rrd_joincount }
catch { unbind part - *           rrd_partcount }
catch { unbind sign - *           rrd_quitcount }
catch { unbind kick - *           rrd_kickcount }

if {$rrd_stats(users)} {
    bind time - "* * * * *" rrd_update
}
if {$rrd_stats(lines)} {
    bind raw  - PRIVMSG     rrd_counter
}
if {$rrd_stats(joins)} {
    bind join - *           rrd_joincount
    bind part - *           rrd_partcount
    bind sign - *           rrd_quitcount
    bind kick - *           rrd_kickcount
}

putlog "rrdstats v$rrd_version by Vetinari <iranitev@gmx.net> loaded..."
