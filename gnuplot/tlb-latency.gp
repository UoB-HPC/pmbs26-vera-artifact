# Fig: random-order pointer-chase latency vs region size, 2 MiB huge pages.
# One column wide.
# Data: dat/tlb-latency.dat  (bytes label grace vera turin gnr)
#       dat/tlb-cache.dat    (chip level bytes latency-at-that-size), from prep_data.py
#
# Layout (top to bottom): a label strip with one row of cache-boundary labels
# per chip, the latency plot, then the key. The strip is a separate small plot
# that shares the x axis, so the latency axis only has to span the data
# (0.4 - 400 ns) and the 100 - 200 ns region keeps readable height.
# Each boundary is one dashed line at the true cache size, from its label in
# the strip down to the x axis; a dot marks where it crosses the chip's own
# curve. Two chips with the same size share one line:
#   TLBSTYLE = 1 (default): its dashes alternate between the two chip colours
#                (segments from dat/tlb-dash.dat, written by prep_data.py)
#   TLBSTYLE = 2: every line is neutral grey; the chip is told by the colour
#                of the label and of the dot
load "../style.gp"
W = COLW ; H = 3.28
eval term(W, H)
set output outname("tlb-latency")
D = "../dat/tlb-latency.dat"
C = "../dat/tlb-cache.dat"
S = "../dat/tlb-dash.dat"
if (!exists("TLBSTYLE")) TLBSTYLE = 1

# vertical layout, inches from the top
STRIP_IN = 0.62          # 4 label rows
PLOT_IN  = 1.95
sy(y) = 1.0 - y / H
LM = 0.15 ; RM = 0.97    # screen fractions, shared by both panels

XMIN = 3000 ; XMAX = 5.5e9
YMIN = 0.4  ; YMAX = 400    # Vera main memory reaches ~307 ns at 4 GiB

# "lc variable" / "tc variable" pick linetype 1..4 from the last column,
# so give those the chip colours
do for [i=1:4] { set linetype i lc rgb word(C_GRACE." ".C_VERA." ".C_AMD." ".C_INTEL, i) }
# (text drawn "with labels" gets backslash escapes processed, hence the \\)
ty(t) = YMIN * (YMAX/YMIN)**t      # plot fraction -> latency (log axis)
lab(s) = '{\\setlength{\\fboxsep}{0.6pt}\\colorbox{white}{' . s . '}}'
row(chip) = 3.5 - chip       # strip row of chip 0..3 (Grace on top)

set multiplot

# --- label strip ----------------------------------------------------------------
set lmargin at screen LM ; set rmargin at screen RM
set tmargin at screen 1.0 ; set bmargin at screen sy(STRIP_IN)
set logscale x 2
set xrange [XMIN:XMAX] ; set yrange [0:4]
unset border ; unset tics ; unset grid ; unset key
if (TLBSTYLE == 1) {
    plot S index 0 u 1:2:(0):($3-$2):($4+1) w vectors nohead lw 2.2 lc variable, \
         C u 6:(row($1)):(lab(strcol(2))):($1+1) w labels center tc variable
} else {
    plot C u 6:(row($1)):(0):(-row($1)) w vectors nohead dt (4,3) lw 1.6 lc rgb C_REF, \
         C u 6:(row($1)):(lab(strcol(2))):($1+1) w labels center tc variable
}

# --- latency plot -----------------------------------------------------------------
set tmargin at screen sy(STRIP_IN) ; set bmargin at screen sy(STRIP_IN + PLOT_IN)
set border 3 lw 0.8
set tics nomirror out scale 0.6
set logscale y 10
set yrange [YMIN:YMAX]
# x: labels every 16x, unlabelled major ticks at the powers of 4 between,
# minor ticks (and grid lines) at the odd powers of 2
set xtics ("4K" 2**12, "" 2**14, "64K" 2**16, "" 2**18, "1M" 2**20, "" 2**22, \
           "16M" 2**24, "" 2**26, "256M" 2**28, "" 2**30, "4G" 2**32)
do for [k=13:31:2] { set xtics add ("" 2**k 1) }
# y: labelled 1-2-5 steps, minor ticks (and grid lines) at 2..9 of each decade
set ytics ("0.5" 0.5, "1" 1, "2" 2, "5" 5, "10" 10, "20" 20, "50" 50, "100" 100, "200" 200, "" 400)
set mytics 10
@GRID_XY_MINOR
set xlabel 'Region size (bytes)' offset 0,0.4
set ylabel 'Access latency (ns)'
set key at screen 0.5, screen sy(STRIP_IN + PLOT_IN + 0.42) center top horizontal maxrows 2 \
    Left reverse samplen 1.5 width -3

CURVES = 'D u 1:3 w lp ls 1 t L_GRACE, D u 1:4 w lp ls 2 t L_VERA, D u 1:5 w lp ls 4 t L_AMD, D u 1:6 w lp ls 5 t L_INTEL, '
if (TLBSTYLE == 1) {
    plot @CURVES \
         S index 1 u 1:(ty($2)):(0):(ty($3) - ty($2)):($4+1) w vectors nohead lw 2.2 lc variable notitle, \
         C u 3:4:($1+1) w p pt 7 ps 0.65 lc variable notitle
} else {
    plot @CURVES \
         C u 6:(YMAX):(0):(YMIN - YMAX) w vectors nohead dt (4,3) lw 1.6 lc rgb C_REF notitle, \
         C u 3:4:($1+1) w p pt 7 ps 0.65 lc variable notitle
}

unset multiplot
