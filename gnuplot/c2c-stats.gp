# Fig: distribution of core-to-core latencies over all core pairs, per chip.
# One column wide.   Data: dat/c2c-stats.dat  (stat grace vera turin gnr)
load "../style.gp"
W = COLW ; H = 2.25
eval term(W, H)
set output outname("c2c-stats")
D = "../dat/c2c-stats.dat"

NS = 4 ; BW = 0.2
array SC[NS] = [C_GRACE, C_VERA, C_AMD, C_INTEL]
array SL[NS] = [L_GRACE, L_VERA, L_AMD, L_INTEL]
set boxwidth BW*BAR_FILL absolute
set style fill solid 1 border lc rgb "black"

set xrange [-0.55:3.55]
set yrange [0:250]
set ytics 0, 50
set ylabel 'Latency (ns), lower is better'
set xtics scale 0
set rmargin 1.5     # fixed: gnuplot cannot measure LaTeX tick labels
set bmargin 3.0     # room for two-line group labels
# two-row key above the plot, centred (gkey_setup in style.gp)
unset key
set tmargin at screen 1 - 0.42/H
eval hkey_arrays(NS) ; HK_Y = 1 - 0.11/H
do for [i=1:NS] { HK_T[i] = SL[i] ; HK_BOX[i] = 1 ; HK_FC[i] = SC[i] ; HK_EC[i] = "#000000" ; HK_V[i] = 0 }
eval gkey_setup

plot D u 0:(NaN):xtic(1) notitle, \
     for [i=1:NS] D u (bar_x($0,i-1,NS,BW)):(column(i+1)) w boxes lc rgb SC[i] t SL[i], \
     for [i=1:NS] D u (bar_x($0,i-1,NS,BW)):(column(i+1)):(v0(column(i+1))) \
         w labels rotate by 90 left offset @ROTOFF notitle
