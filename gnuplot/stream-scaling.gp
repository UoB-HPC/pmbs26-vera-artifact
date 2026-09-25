# Fig: STREAM triad bandwidth vs cores (round-robin placement, stride 8).
# One column wide.   Data: dat/stream-scaling.dat (index 0..3 = Grace, Vera, AMD, Intel)
load "../style.gp"
eval term(COLW, 2.45)
set output outname("stream-scaling")
D = "../dat/stream-scaling.dat"

set xlabel 'Cores (1 thread per core)'
set ylabel 'Triad bandwidth (GB/s)'
set xrange [0:97]
set xtics 0, 16
set mxtics 2          # minor x every 8 cores
set yrange [0:1400]
set ytics 0, 200
set mytics 2          # minor y every 100 GB/s
@GRID_XY_MINOR
set key at graph 0.03, graph 0.975 left top Left reverse maxrows 2 width -6 samplen 1.5 spacing 1.1

plot D index 0 u 1:2 w lp ls 1 t L_GRACE, \
     D index 1 u 1:2 w lp ls 2 t L_VERA, \
     D index 2 u 1:2 w lp ls 4 t L_AMD, \
     D index 3 u 1:2 w lp ls 5 t L_INTEL
