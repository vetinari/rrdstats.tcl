#!/usr/bin/tclsh
#!/usr/local/bin/tclsh8.3
#
# mkrrdgraphs.tcl - draw the graphs from the data recorded by rrdstats.tcl
#

# exec sleep 5
proc putlog {txt} {
    puts stderr $txt
}
proc unixtime {} {
    return [clock seconds]
}
if {$argc != 0} {
    puts stdout "Usage: mkrrdgraphs.tcl"
    puts stdout " draw the graphs from the data recorded by rrdstats.tcl"
    exit 1
}
source rrdstats.conf
global rrd_bot_dir
cd $rrd_bot_dir
source scripts/rrdstats-graph.tcl
global rrd_lib
if {$rrd_lib != ""} {
    load $rrd_lib
}
package require Rrd 1.3.1
# package require Rrd 1.0.13
global rrd_stats
foreach name [array names rrd_stats *] {
    if {$name == "ops"} { continue }
    if {$rrd_stats($name)} {
        rrd_draw_graph $name
    }
}
exit 0
