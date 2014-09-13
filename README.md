# rrdstats.tcl

`rrdstats.tcl` is an [eggdrop](http://www.eggheads.org/) script, which
displays the channel stats for join/part/kick, lines spoken, users on channel
as images. It uses the [rrdtool](http://www.rrdtool.org/) for this task.

An example can be found on [http://lost.channelno5.de/~phoenix/daily.html](http://lost.channelno5.de/~phoenix/daily.html)

# Config

The config file `rrdstats.conf` is shared by the eggdrop script
`rrdstats.tcl` and the graph creation script `mkrrdgraphs.tcl`. It should
be placed inside your eggdrop installation dir, usually as
`~/eggdrop/rrdstats.conf`.

## rrd\_time

This is how long the one round of data is kept (in 2001 when this was written,
some people cared about these sizes...). Possible values are:

- one day - uses ~350 kB user stats, ~150 kB line stats, ~100 kB join stats,
per channel
- 1

one week - uses  ~2.4 MB user stats, ~1 MB line stats and ~650 kB join stats
per channel

- 2

one month - this needs ~7.5 MB for user data, ~3 MB for line and ~2 MB for
joins PER CHAN, only activate this if you have enough disk space...

__Warning__: do not change the value once the bot has read the script... OR
delete the `.rrd` files and `.rehash` (all data is lost)

## rrd\_stats(users)

records how many voice/ops/users are on the chan

## rrd\_stats(joins)

joining and leaving the channel

## rrd\_stats(lines)

counts the lines/actions per minute on the chan

## rrd\_stats(length)

length of the spoken lines/actions

## rrd\_stats(words)

words per line / words per action

## rrd\_stats(domain)

stats which domains are present

Set `rrd_stats(NAME)` to `0` if you do not want one type of stats

## rrd\_domains

A list of domains which should be matched together. If you want to filter a
subdomain and also show the domain, add the subdomain before the domain.
Example:

    set rrd_domains {
       *.t-dialin.net *.pppool.de *.de
    }

## rrd\_file

This is the file(s), where RRD keeps it's database, any %chan will be
replaced by the channel name without \#!&+, i.e. the channel \#a\_chan
will have the users rrd file './rrd/a\_chan-users.rrd'.
__Note__: ALWAYS include a %type and %chan...

## rrd\_color(users-cur)

## rrd\_color(ops-cur)

## rrd\_color(voice-cur)

## rrd\_color(lines-cur)

## rrd\_color(actions-cur)

## rrd\_color(joins-cur)

## rrd\_color(parts-cur)

## rrd\_color(quits-cur)

## rrd\_color(kicks-cur)

## rrd\_color(domain-ip)

## rrd\_color(domain-other)

## rrd\_color(domain-1)

## rrd\_color(domain-2)

## rrd\_color(domain-3)

Colors of the graphs for current users/ops/voice/lines/actions...

Use colors like in HTML (NOT names!)... leave them defined, even if
you do not show the stats for them...

## rrd\_chans

Channels for which stats should be made

## rrd\_title(users)

## rrd\_title(lines)

## rrd\_title(words)

## rrd\_title(length)

## rrd\_title(joins)

This is the title of the graph, `%chan` will be replaced by the channel
name.

## rrd\_imgtype

Type of image... supported values are: PNG GIF. The default PNG
is recommended.

## rrd\_graph\_update

Draw the graph every `$rrd_graph_update` minutes. Set to `0` to use the
external command scripts/mkrrdgraphs.tcl to create the graphs from a cron job
(highly recommended). Use a line like this in your crontab to start it every
15 minutes:

    5,20,35,50 * * * * cd $HOME/eggdrop && tclsh ./scripts/mkrrdgraphs.tcl > /dev/null 2>&1

## rrd\_graph

Where should we write the graphs...

ALWAYS have `%type`, `%time`, `%img` and `%chan` in the name :o)

- %img

is the lowercased `$rrd_imgtype`

- %chan

is the same as in `$rrd_file`

- %type

is what kind of stats (users, lines)

- %time

is `daily`, `weekly` or `monthly`

## rrd\_lib

If your eggdrop can not load the rrd lib (`tclrrd.so` from the `tcl/`
subdir of the rrdtool source) automatically from the TCL search path,
use this (the `rrdstats.tcl` and `mkrrdgraphs.tcl` will load it for you)...
else set to ""

## rrd\_bot\_dir

This is the directory, where your bot is installed.
