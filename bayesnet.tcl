package require TclOO

source jbroo.tcl
source util.tcl


oo::class create Graph {
    variable Adj
    accessor Adj

    constructor   {   } { set Adj {} }
    method adj    { v } { if { [dict exists $Adj $v] } { dict get $Adj $v } }
    method insert { args } {
        foreach node $args {
            if { [dict exists $Adj $node] } { return }
            dict set Adj $node {}
        }
    }
    method edge    { args } {
        dict for {u v} $args {
            if { [dict exists $Adj $u] && [dict exists $Adj $v] } {
                dict lappend Adj $u $v
            }
        }
    }
}

oo::class create BayesNet {
    variable Adj
    accessor Adj

    constructor  {      } { set Adj {} }
    method infer { args } {
        set getbool {{ args node } { dict get $args $node }}

        foreach node [dict keys $Adj] {
            if { [$node parents] eq {} } {
                lappend factors [$node p [apply $getbool $args $node]]
                continue
            }
            lappend factors [$node p {*}[mapcan parent [$node parents] {
                list $parent [apply $getbool $args $parent]
            }]]
        }

        expr [join $factors *]
    }
}
oo::define BayesNet { mixin Graph }

oo::class create BayesNode {
    variable name cp
    accessor name cp

    constructor { _name _cpt } {
        set name $_name
        set cp  [my _parseCP $_cpt]
    }
    method parents {      } { lindex $cp 0 }
    method cpt     {      } { lindex $cp 1 }
    method p        { args } {
        if { [llength [my cpt]] == 1 } {
            if { $args eq "f" } {
                return [expr { 1 - [my cpt] }]
            }
            return [my cpt]
        }
        dict get [my cpt] [my _cptkey {*}$args]
    }
    method _parseCP { cptdef } {
        if { [llength $cptdef] == 1 } { return [list {} {*}$cptdef] }

        set _cpt [lrange [split $cptdef \n] 1 end-1]
        set cpt  {}

        set parents [lrange [lindex $_cpt 0] 0 end-1]
        foreach row [lrange $_cpt 1 end] {
            set bools  [lrange $row 0 end-1]
            set cptkey [my _cptkey {*}[concat {*}[zip $parents $bools]]]

            dict set cpt $cptkey [lindex $row end]
        }
        
        return [list $parents $cpt]
    }
    method _cptkey { args } {
        dict for {k v} $args { set $k $v }
        join [lmap k [lsort [dict keys $args]] { set $k }] {}
    }

    export parents
}


## ------------------------------ ##

set g [BayesNet new]

set burglary   [BayesNode new Burglary   { 0.001 }]
set earthquake [BayesNode new Earthquake { 0.002 }]

set alarm [BayesNode new Alarm "
    $burglary $earthquake P(Alarm)
    t         t           0.95
    t         f           0.94
    f         t           0.29
    f         f           0.001
"]

set jcalls [BayesNode new JohnCalls "
    $alarm P(J)
    t      0.90
    f      0.5
"]

set mcalls [BayesNode new MaryCalls "
    $alarm P(M)
    t      0.70
    f      0.01
"]

$g insert $burglary $earthquake $alarm $mcalls $jcalls

puts [format "%.6f" [$g infer $burglary f $earthquake f $alarm t $jcalls t $mcalls t]]

