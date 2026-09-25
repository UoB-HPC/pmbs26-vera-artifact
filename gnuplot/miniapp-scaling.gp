# Fig: miniapp strong scaling, speedup vs ONE Grace core, 2x2 panels.
# One column wide.   Data: dat/miniapp-scaling.dat
#   index 0..3 = CloverLeaf, miniBUDE, TeaLeaf, Neutral
#   columns: cores grace vera vera_smt turin gnr
# Lines with markers every 8 cores and a shaded Vera SMT off/on band, as in Fig 7.
load "../style.gp"
W = COLW ; H = (exists("SMTBAND") && !SMTBAND ? 4.1 : 4.25)
eval term(W, H)
set output outname("miniapp-scaling")
D = "../dat/miniapp-scaling.dat"
# SMTBAND = 1 (default): shaded band between Vera SMT off and SMT on;
#           0: no band, the SMT-on run is only its dashed line
if (!exists("SMTBAND")) SMTBAND = 1
PRE = (SMTBAND ? BAND : '')

array T[4] = ['CloverLeaf (bm32\_short)', 'miniBUDE (bm1)', 'TeaLeaf (bm\_5e\_2)', 'Neutral (stream)']
array LS[5] = [11, 12, 13, 14, 15]   # markers every PI cores (style.gp)
array LT[5] = [L_GRACE, L_VERA, L_VERA_SMT, L_AMD, L_INTEL]

set xrange [0:97]
set xtics 0, 32
set mxtics 2
@GRID_XY
set format y "%g"

# Layout in inches (from the top): title, panel, x tics, [x label], ...
LM_IN = 0.46 ; RM_IN = 0.04 ; GAPX_IN = 0.44
PW_IN = (W - LM_IN - RM_IN - GAPX_IN) / 2.0
TITLE_IN = 0.20 ; XTIC_IN = 0.18 ; XLAB_IN = 0.18 ; ROWGAP_IN = 0.12
PH_IN = 1.25
KEY_IN = 0.55
sx(x) = x / W ; sy(y) = 1.0 - y / H
PTOP1 = TITLE_IN
PTOP2 = TITLE_IN + PH_IN + XTIC_IN + ROWGAP_IN + TITLE_IN

set multiplot
do for [i=1:4] {
    col = (i-1) % 2 ; row = (i-1) / 2
    x0 = LM_IN + col*(PW_IN + GAPX_IN)
    y0 = (row == 0) ? PTOP1 : PTOP2
    set lmargin at screen sx(x0) ; set rmargin at screen sx(x0 + PW_IN)
    set tmargin at screen sy(y0) ; set bmargin at screen sy(y0 + PH_IN)
    set title T[i] offset 0,-0.7
    # y axis: 0 .. data max, at most 5 tick intervals
    YMAX = 0 ; set autoscale y ; set autoscale x   # stats obeys the current ranges
    do for [c=2:6] {
        undefine STATS_*
        stats D index (i-1) u (column(c)) nooutput
        if (exists("STATS_max")) { if (STATS_max > YMAX) { YMAX = STATS_max } }
    }
    if (YMAX <= 0) { YMAX = 1 }
    YS = nicestep(YMAX, 4)
    set yrange [0:YS*ceil(YMAX/YS*1.02)]
    set ytics 0, YS ; set xrange [0:97]
    if (row == 1) { set xlabel 'Cores' offset 0,0.5 } else { unset xlabel }
    if (i == 4) {
        # one y label for the whole grid, centred on both rows
        set label 99 'Speedup vs 1 Grace core ($\times$)' at screen 0.03, \
            screen sy(PTOP1 + (PTOP2 + PH_IN - PTOP1)/2) center rotate by 90
        # one shared key for the whole figure, below the panels
        set key at screen 0.5, screen sy(PTOP2 + PH_IN + XTIC_IN + XLAB_IN + 0.04) center top \
            Left reverse maxrows 4 samplen 1.3 width -0.5 spacing 1.18
        plot @PRE for [s=1:5] D index (i-1) u 1:(column(s+1)) w lp ls LS[s] t LT[s], \
             x w l ls 9 t 'Linear scaling', \
             (SMTBAND ? -1 : NaN) w filledcurves y1=0 fc rgb C_SMT_GAIN fs solid 0.55 noborder t (SMTBAND ? 'SMT on faster' : ''), \
             (SMTBAND ? -1 : NaN) w filledcurves y1=0 fc rgb C_SMT_LOSS fs solid 0.75 noborder t (SMTBAND ? 'SMT on slower' : '')
    } else {
        unset key
        plot @PRE for [s=1:5] D index (i-1) u 1:(column(s+1)) w lp ls LS[s] notitle, \
             x w l ls 9 notitle
    }
}
unset multiplot
