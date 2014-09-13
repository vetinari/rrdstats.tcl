#
# rrdstats-graph.tcl - draw channel stats graphics with the rrdtool
#
# Author: Hanno Hecker <vetinari@ankh-morp.org>
#
# Changelog: see rrdstats.tcl

proc rrd_draw_graph {what} {
    global rrd_color rrd_graph rrd_title rrd_chans rrd_file rrd_imgtype rrd_time
    set cur_time [exec date +%Y-%m-%d\ %H:%M]
    foreach chan $rrd_chans {
        set picname ""
        set title ""
        set file ""
        regsub -all -- "%chan" $rrd_graph [string range $chan 1 end] picname
        regsub -all -- "%type" $picname $what picname
        regsub -all -- "%img"  $picname [string tolower $rrd_imgtype] picname
        regsub -all -- "%chan" $rrd_title($what) $chan title
        regsub -all -- "%chan" $rrd_file [string range $chan 1 end] file
        ## set start [list "1 day" "7 days" "31 days"]
        ## set times [list "daily" "weekly" "monthly"]
        set start [list "1 day" "7 days" "31 days" "1 year"]
        set times [list "daily" "weekly" "monthly" "yearly"]
        switch -exact -- $what {
            users {
                regsub -all -- "%type" $file users file
                set cur_u $rrd_color(users-cur)
                set cur_o $rrd_color(ops-cur)
                set cur_v $rrd_color(voice-cur)
                set graph ""
                global rrd_stats
                ## for {set i 0} {$i <= $rrd_time} {incr i} { }
                for {set i 0} {$i <= 3} {incr i} {
                    regsub -all -- "%time" $picname [lindex $times $i] graph
                    if {$rrd_stats(ops)} {
                        set defs "DEF:curOps=$file:numOps:AVERAGE DEF:curVoice=$file:numVoice:AVERAGE CDEF:Ops=curOps,curVoice,+"
                        set area "AREA:Ops${cur_o}:Ops AREA:curVoice${cur_v}:Voice"
                    } else {
                        set defs ""
                        set area ""
                    }
                    putlog "rrdstats: drawing $graph ..."
                    eval "Rrd::graph $graph --title \"$title\" --lower-limit 0 \
                        \"--start=now - [lindex $start $i]\" \
                        --imgformat $rrd_imgtype  \
                        --watermark \"created $cur_time\" \
                        --slope-mode \
                        DEF:curUsers=$file:numUsers:AVERAGE \
                        $defs AREA:curUsers${cur_u}:Users $area"
                }
            }

            domain {
                global rrd_domains rrd_binary
                regsub -all -- "%type" $file "domain" file
                set dom_i $rrd_color(domain-ip)
                set dom_o $rrd_color(domain-other)

                set l [llength $rrd_domains]
                for {set i 1} {$i <= $l} {incr i} {
                    eval "set dom_$i \$rrd_color(domain-$i)"
                }

                set graph ""
                for {set i 0} {$i <= $rrd_time} {incr i} {
                    regsub -all -- "%time" $picname [lindex $times $i] graph
                    set defs [list]
                    set lines [list]
                    for {set d 1} {$d <= $l} {incr d} {
                        lappend defs "DEF:dom_${d}=$file:domain_${d}:AVERAGE"
                        set c "dom_$d"
                        set c [eval "set \$c"]
                        set n [lindex $rrd_domains [expr $d - 1]]
                        lappend lines "LINE2:dom_${d}${c}:${n}"
                    }
                    set defs [join $defs " "]
                    set lines [join $lines " "]
                    switch $i {
                        0 { set mystart [expr [unixtime] - 86400] }
                        1 { set mystart [expr [unixtime] - 604800] }
                        2 { set mystart [expr [unixtime] - 2678400] }
                        default { set mystart [expr [unixtime] - 604800] }
                    }
                    putlog "rrdstats: drawing $graph ..."
                    eval "Rrd::graph $graph --title \"$title\" --lower-limit 0 \
                        --imgformat $rrd_imgtype --start=$mystart \
                        --watermark \"created $cur_time\" \
                        --slope-mode \
                        DEF:ip=$file:domain_IP:AVERAGE \
                        DEF:other=$file:domain_other:AVERAGE $defs \
                        LINE2:other${dom_o}:Others LINE2:ip${dom_i}:IP $lines"
                }
            }

            lines {
                regsub -all -- "%type" $file lines file
                set cur_l $rrd_color(lines-cur)
                set cur_a $rrd_color(actions-cur)
                set graph ""
                ## for {set i 0} {$i <= $rrd_time} {incr i} { }
                for {set i 0} {$i <= 3} {incr i} {
                    regsub -all -- "%time" $picname [lindex $times $i] graph
                    putlog "rrdstats: drawing $graph ..."
                    Rrd::graph $graph \
                        --title $title \
                        --lower-limit 0 \
                        "--start=now - [lindex $start $i]" \
                        --imgformat $rrd_imgtype \
                        --watermark "created $cur_time" \
                        --slope-mode \
                        DEF:curLines=$file:numLines:AVERAGE \
                        DEF:curActions=$file:numActions:AVERAGE \
                        CDEF:lines=curLines,curActions,+ \
                        CDEF:a_lines=lines,5,/ \
                        CDEF:a_act=curActions,5,/ \
                        "AREA:a_lines${cur_l}:Lines/Minute" \
                        "AREA:a_act${cur_a}:Actions/Minute"
                }
            }

            words {
                set cur_l $rrd_color(lines-cur)
                set cur_a $rrd_color(actions-cur)
                set graph ""
                regsub -all -- "%type" $file lines file
                ## for {set i 0} {$i <= $rrd_time} {incr i} { }
                for {set i 0} {$i <= 3} {incr i} {
                    regsub -all -- "%time" $picname [lindex $times $i] graph
                    putlog "rrdstats: drawing $graph ..."
                    Rrd::graph $graph \
                        --title $title \
                        --lower-limit 0 \
                        --imgformat $rrd_imgtype \
                        "--start=now - [lindex $start $i]" \
                        --watermark "created $cur_time" \
                        --slope-mode \
                        DEF:curLines=$file:avgLineWords:AVERAGE \
                        DEF:curActions=$file:avgActWords:AVERAGE \
                        CDEF:lines=curLines,curActions,+ \
                        "AREA:lines${cur_l}:Words/Lines" \
                        "AREA:curActions${cur_a}:Words/Action"
                }
            }

            length {
                set cur_l $rrd_color(lines-cur)
                set cur_a $rrd_color(actions-cur)
                set graph ""
                regsub -all -- "%type" $file lines file
                ## for {set i 0} {$i <= $rrd_time} {incr i} { }
                for {set i 0} {$i <= 3} {incr i} {
                    regsub -all -- "%time" $picname [lindex $times $i] graph
                    putlog "rrdstats: drawing $graph ..."
                    Rrd::graph $graph \
                        --title $title \
                        --lower-limit 0 \
                        --imgformat $rrd_imgtype \
                        --watermark "created $cur_time" \
                        --slope-mode \
                        "--start=now - [lindex $start $i]" \
                        DEF:curLines=$file:avgLineLength:AVERAGE \
                        DEF:curActions=$file:avgActLength:AVERAGE \
                        CDEF:lines=curLines,curActions,+ \
                        "AREA:lines${cur_l}:Length of Lines" \
                        "AREA:curActions${cur_a}:Length of Actions"
                }
            }

            joins {
                set cur_j $rrd_color(joins-cur)
                set cur_p $rrd_color(parts-cur)
                set cur_q $rrd_color(quits-cur)
                set cur_k $rrd_color(kicks-cur)
                set graph ""
                regsub -all -- "%type" $file "joins" file
                ## for {set i 0} {$i <= $rrd_time} {incr i} { }
                for {set i 0} {$i <= 3} {incr i} {
                    regsub -all -- "%time" $picname [lindex $times $i] graph
                    putlog "rrdstats: drawing $graph ..."
                    Rrd::graph $graph \
                        --title $title \
                        --lower-limit 0 \
                        "--start=now - [lindex $start $i]" \
                        --watermark "created $cur_time" \
                        --slope-mode \
                        --imgformat $rrd_imgtype \
                        DEF:Joins=$file:numJoins:AVERAGE \
                        DEF:Quits=$file:numQuits:AVERAGE \
                        DEF:Parts=$file:numParts:AVERAGE \
                        DEF:Kicks=$file:numKicks:AVERAGE \
                        LINE2:Joins${cur_j}:Joins \
                        LINE2:Quits${cur_q}:Quits \
                        LINE2:Parts${cur_p}:Parts \
                        LINE2:Kicks${cur_k}:Kicks
                }
            }
        }
    }
}
