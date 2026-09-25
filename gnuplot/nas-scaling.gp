# Fig: NAS class B strong scaling, Mop/s vs cores, one panel per kernel.
# Full text width (figure*).   Data: dat/nas-scaling.dat
#   index 0..8 = BT CG EP FT IS LU MG SP UA
#   columns: cores grace vera vera_smt turin gnr   (vera_smt: 2 threads per core)
#
# SMTVIEW picks how Vera SMT on (2 threads per core) is shown:
#   0: not at all (four chips, one thread per core)
#   1: shaded band from Vera SMT off to SMT on, no separate SMT-on line
#   2: SMT-on line with markers + shaded band (the earlier version)
#   3: SMT-on line removed from the main panels; a strip under each panel
#      shows Vera SMT on / SMT off (1 = no change), green above 1, red below
load "../style.gp"
if (!exists("SMTVIEW")) SMTVIEW = 2      # chosen: SMT-on line + band
D = "../dat/nas-scaling.dat"
STRIP = (SMTVIEW == 3)
W = TEXTW ; H = (STRIP ? 4.1 : 3.3)
eval term(W, H)
set output outname("nas-scaling")

array K[9] = ["BT", "CG", "EP", "FT", "IS", "LU", "MG", "SP", "UA"]
# styles 11-15, PI, C_SMT_GAIN/LOSS and BAND come from style.gp
array LS[5] = [11, 12, 13, 14, 15]
array LT[5] = [L_GRACE, L_VERA, L_VERA_SMT_S, L_AMD, L_INTEL]
array SHOW[5] = [1, 1, (SMTVIEW == 2), 1, 1]      # series drawn as lines
# band edge only (SMTVIEW 1): a thin line on the SMT-on side of the band
BANDEDGE = 'D index (i-1) u 1:4 w l lc rgb C_VERA lw 0.8 dt 1 notitle, '
if (SMTVIEW == 0 || SMTVIEW == 3) { PRE = '' }
if (SMTVIEW == 1) { PRE = BAND . BANDEDGE }
if (SMTVIEW == 2) { PRE = BAND }

@GRID_XY
set mxtics 2

# Layout in inches: 5 columns x 2 rows of panels; the key fills the empty 10th slot.
NC = 5
LM_IN = 0.64 ; RM_IN = 0.20 ; GAPX_IN = 0.46   # RM_IN: room for the key beside UA
PW_IN = (W - LM_IN - RM_IN - (NC-1)*GAPX_IN) / NC
TITLE_IN = 0.20 ; XTIC_IN = 0.18 ; XLAB_IN = 0.17 ; ROWGAP_IN = 0.02
RH_IN = (STRIP ? 0.40 : 0) ; RGAP_IN = (STRIP ? 0.08 : 0)     # ratio strip
PH_IN = (H - 2*TITLE_IN - 2*XTIC_IN - XLAB_IN - ROWGAP_IN - 0.02 - 2*(RH_IN + RGAP_IN)) / 2.0
sx(x) = x / W ; sy(y) = 1.0 - y / H
PTOP1 = TITLE_IN
PTOP2 = PTOP1 + PH_IN + RGAP_IN + RH_IN + XTIC_IN + ROWGAP_IN + TITLE_IN

set multiplot
do for [i=1:9] {
    col = (i-1) % NC ; row = (i-1) / NC
    x0 = LM_IN + col*(PW_IN + GAPX_IN)
    y0 = (row == 0) ? PTOP1 : PTOP2
    NUMS = (row == 1 || col == NC-1)             # x numbers under this panel
    set lmargin at screen sx(x0) ; set rmargin at screen sx(x0 + PW_IN)
    set tmargin at screen sy(y0) ; set bmargin at screen sy(y0 + PH_IN)
    set title K[i] offset 0,-0.7
    set border 3 ; set ytics ; set grid

    # y axis 0 .. max over the series drawn, <= 4 intervals, "k" suffix
    set autoscale xy
    YMAX = 0
    do for [c=2:6] {
        if (SHOW[c-1] || (c == 4 && SMTVIEW > 0 && SMTVIEW < 3)) {
            undefine STATS_*
            stats D index (i-1) u (column(c)) nooutput
            if (exists("STATS_max")) { if (STATS_max > YMAX) { YMAX = STATS_max } }
        }
    }
    YS = nicestep(YMAX, 4)
    YTOP = YS*ceil(YMAX/YS*1.02)
    set yrange [0:YTOP]
    eval ktics(YTOP, YS)
    set xrange [0:97] ; set xtics 0, 32
    set format x ((NUMS && !STRIP) ? '%g' : '')
    if (row == 1 && !STRIP) { set xlabel 'Cores' offset 0,0.5 } else { unset xlabel }
    if (i == 9) {
        set label 98 'Throughput (Mop/s), class B' at screen 0.012, \
            screen sy(PTOP1 + (PTOP2 + PH_IN - PTOP1)/2) center rotate by 90
    }
    unset key
    plot @PRE for [s=1:5] D index (i-1) u 1:(SHOW[s] ? column(s+1) : NaN) w lp ls LS[s] notitle
    unset label 98

    if (STRIP) {
        unset title
        set tmargin at screen sy(y0 + PH_IN + RGAP_IN)
        set bmargin at screen sy(y0 + PH_IN + RGAP_IN + RH_IN)
        set yrange [0.5:1.5] ; set ytics ("0.5" 0.5, "1" 1, "" 1.5)   # no "1.5": it would touch the panel's "0"
        set format x (NUMS ? '%g' : '')
        if (row == 1) { set xlabel 'Cores' offset 0,0.5 } else { unset xlabel }
        set grid xtics
        plot D index (i-1) u 1:($4/$3):(1) w filledcurves above fc rgb C_SMT_GAIN fs solid 0.8 noborder notitle, \
             D index (i-1) u 1:($4/$3):(1) w filledcurves below fc rgb C_SMT_LOSS fs solid 0.9 noborder notitle, \
             1 w l lc rgb C_REF lw 1 dt 2 notitle, \
             D index (i-1) u 1:($4/$3) w l lc rgb C_VERA lw 1.4 notitle
        set grid ytics
    }
}
# Key: an empty plot in the 10th slot that only draws its key.
# Strips (SMTVIEW 3): Vera SMT on / SMT off at each core count.
unset label ; unset title ; unset xlabel ; unset ylabel ; unset grid
unset tics ; unset border
x0 = LM_IN + 4*(PW_IN + GAPX_IN)
UA_R = LM_IN + 3*(PW_IN + GAPX_IN) + PW_IN       # right edge of the UA panel
set lmargin at screen sx(UA_R + 0.02) ; set rmargin at screen 1
set tmargin at screen sy(PTOP2 - 0.05) ; set bmargin at screen 0
set xrange [0:1] ; set yrange [0:1]
set key at graph 0, graph 1 left top vertical Left reverse samplen 0.9 spacing 1.1 width -1.5
if (SMTVIEW == 0) {
    plot for [s in "1 2 4 5"] -1 w lp ls LS[s+0] t LT[s+0]
}
if (SMTVIEW == 1) {
    plot for [s in "1 2 4 5"] -1 w lp ls LS[s+0] t LT[s+0], \
         -1 w filledcurves y1=0 fc rgb C_SMT_GAIN fs solid 0.55 noborder t 'Vera SMT faster', \
         -1 w filledcurves y1=0 fc rgb C_SMT_LOSS fs solid 0.75 noborder t 'Vera SMT slower'
}
if (SMTVIEW == 2) {
    plot for [s=1:5] -1 w lp ls LS[s] t LT[s], \
         -1 w filledcurves y1=0 fc rgb C_SMT_GAIN fs solid 0.55 noborder t 'SMT on faster', \
         -1 w filledcurves y1=0 fc rgb C_SMT_LOSS fs solid 0.75 noborder t 'SMT on slower'
}
if (SMTVIEW == 3) {
    plot for [s in "1 2 4 5"] -1 w lp ls LS[s+0] t LT[s+0], \
         -1 w filledcurves y1=0 fc rgb C_SMT_GAIN fs solid 0.8 noborder t 'Strip: SMT faster', \
         -1 w filledcurves y1=0 fc rgb C_SMT_LOSS fs solid 0.9 noborder t 'Strip: SMT slower'
}
unset multiplot
