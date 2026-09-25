# Fig: NAS class D on Vera: speedup from running 2 threads per core (SMT on,
# 176 threads) over the baseline of 1 thread per core (SMT off, 88 threads).
# One column wide.   Data: dat/nas-smt.dat  (kernel ratio)
load "../style.gp"
W = COLW ; H = 2.85
eval term(W, H)
set output outname("nas-smt")
D = "../dat/nas-smt.dat"

stats D u 0 nooutput ; NG = STATS_records
set boxwidth 0.6 absolute
set xrange [-0.6:NG-0.4]
set yrange [0:1.55]
set ytics 0, 0.2 format "%.1f"
# LOGY (style.gp): 1 = log2 axis, bars from 1x; 2 = log2 axis, lollipops.
# 0.5-2 keeps 1x in the middle, so gain and loss read at the same scale.
if (LOGY) { eval log_axis(0.5, 2) }
set xtics scale 0
set xlabel 'NAS kernel (class D)' offset 0,0.3
set ylabel 'Speedup vs 1 thread per core ($\times$)'   # one line: needs H >= 2.9in
set key outside top center Left reverse samplen 1.6 width -2
# 1x (= 1 thread per core): the same axis line as the other speedup charts
eval REFLINE

BW8 = 0.6
LAB = 'Vera, 2 threads per core (176 threads)'
if (LOGY == 0) {
plot D u 0:(NaN):xtic(1) notitle, \
     D u 0:2 w boxes lc rgb C_VERA_SMT fs solid 1 border lc rgb C_VERA t LAB, \
     D u 0:2 w boxes lc rgb C_VERA fs transparent pattern 5 border lc rgb C_VERA notitle, \
     D u 0:2:(v2($2)) w labels center offset 0,0.55 notitle
}
if (LOGY == 1) {
plot D u 0:(NaN):xtic(1) notitle, \
     D u 0:2:($0-BW8/2):($0+BW8/2):(1):2 w boxxyerror lc rgb C_VERA_SMT fs solid 1 border lc rgb C_VERA t LAB, \
     D u 0:2:($0-BW8/2):($0+BW8/2):(1):2 w boxxyerror lc rgb C_VERA fs transparent pattern 5 border lc rgb C_VERA notitle, \
     D u 0:($2 >= 1 ? $2 : NaN):(v2($2)) w labels center offset 0,0.55 notitle, \
     D u 0:($2 < 1 ? $2 : NaN):(v2($2)) w labels center offset 0,-0.55 notitle
}
if (LOGY == 2) {
set style line 40 lc rgb C_VERA lw 2.2 pt 6 ps 0.9
plot D u 0:(NaN):xtic(1) notitle, \
     D u 0:(1):(0):($2-1) w vectors nohead ls 40 notitle, \
     D u 0:2 w p ls 40 t LAB, \
     D u 0:($2 >= 1 ? $2 : NaN):(v2($2)) w labels center offset 0,0.75 notitle, \
     D u 0:($2 < 1 ? $2 : NaN):(v2($2)) w labels center offset 0,-0.75 notitle
}
