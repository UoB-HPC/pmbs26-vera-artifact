# Fig: core-to-core latency for every pair of cores, 2x2 heatmaps, one shared
# logarithmic colour scale. One column wide.
# Data: dat/c2c-<arch>.csv = the raw benchmark output, read directly.
#   It is a lower-triangular CSV: row i, column j = latency between cores i and j
#   (j < i), other cells empty. gnuplot's "matrix" keyword reads it as a grid:
#   column 1 = x (column index), column 2 = y (row index), column 3 = value.
#   Empty cells are missing, so they stay transparent. Plotting it a second time
#   with x and y swapped (u 2:1:3) fills the upper triangle.
#   The x86 files have one extra, bogus core (97x97): the axis ranges below stop
#   at the real core count, which crops it.
load "../style.gp"
# Vertical layout in inches, top to bottom (panels are square).
W = COLW
LM_IN = 0.50; RM_IN = 0.06; GAPX_IN = 0.34        # left/right margins, column gap
PW_IN = (W - LM_IN - RM_IN - GAPX_IN) / 2.0      # panel side
TITLE_IN = 0.20; XTIC_IN = 0.19; XLAB_IN = 0.19; ROWGAP_IN = 0.08
CB_GAP_IN = 0.14; CB_IN = 0.09; CBTIC_IN = 0.19; CBLAB_IN = 0.19
H = TITLE_IN + PW_IN + XTIC_IN + ROWGAP_IN + TITLE_IN + PW_IN + XTIC_IN + XLAB_IN \
    + CB_GAP_IN + CB_IN + CBTIC_IN + CBLAB_IN
eval term(W, H)
set output outname("c2c-heatmaps")

# green = low latency, yellow = middle, red = high (same map as before)
set palette defined (0 "#2f9e44", 1 "#ffe066", 2 "#d90429")
set logscale cb
set cbrange [30:200]
set cbtics ("30" 30, "40" 40, "60" 60, "100" 100, "150" 150, "200" 200) scale 0.5
set datafile separator comma
unset grid
set tics out scale 0.5
set border 15 lw 0.6
set xtics 0, 32 ; set ytics 0, 32
set mxtics 2 ; set mytics 2

array F[4] = ["grace", "vera", "turin-9r45", "gnr"]
array T[4] = ["Grace (72c)", "Vera (88c)", "EPYC 9R45 (96c)", "Xeon 6975P-C (96c)"]
array N[4] = [72, 88, 96, 96]

# inches -> screen fractions
sx(x) = x / W ; sy(y) = 1.0 - y / H            # y measured from the top
PTOP1 = TITLE_IN
PTOP2 = TITLE_IN + PW_IN + XTIC_IN + ROWGAP_IN + TITLE_IN
CBTOP = PTOP2 + PW_IN + XTIC_IN + XLAB_IN + CB_GAP_IN
set multiplot
do for [i=1:4] {
    col = (i-1) % 2 ; row = (i-1) / 2
    x0 = LM_IN + col*(PW_IN + GAPX_IN)
    y0 = (row == 0) ? PTOP1 : PTOP2
    set lmargin at screen sx(x0)
    set rmargin at screen sx(x0 + PW_IN)
    set tmargin at screen sy(y0)
    set bmargin at screen sy(y0 + PW_IN)
    set title T[i] offset 0,-0.7
    set xrange [-0.5:N[i]-0.5] ; set yrange [N[i]-0.5:-0.5]   # core 0 top-left
    if (row == 1) { set xlabel 'Core ID' offset 0,0.5 } else { unset xlabel }
    if (col == 0) { set ylabel 'Core ID' offset 0.4,0 } else { unset ylabel }
    if (i == 4) {
        set colorbox horizontal user origin screen sx(LM_IN), screen sy(CBTOP + CB_IN) \
            size screen sx(W - LM_IN - RM_IN), screen CB_IN / H
        set label 99 'Core-to-core latency (ns), lower is better' at screen 0.5*(sx(LM_IN)+1-sx(RM_IN)), \
            screen sy(CBTOP + CB_IN + CBTIC_IN + 0.5*CBLAB_IN) center
    } else { unset colorbox }
    FILE = sprintf("../dat/c2c-%s.csv", F[i])
    plot FILE matrix u 1:2:3 with image notitle, \
         FILE matrix u 2:1:3 with image notitle
}
unset multiplot
