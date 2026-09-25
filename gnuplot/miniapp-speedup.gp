# Fig: miniapps, whole-chip speedup vs whole-chip Grace, plus one summary
# group (geometric mean of the per-app best of SMT off/on).
# Data: dat/miniapp-speedup.dat  (app vera vera_smt turin gnr short_label)
#
# WIDE = 0 (default): one column; tick labels are the app names, rotated.
# WIDE = 1: full text width (figure*), app name over test case:
#     gnuplot -e "WIDE=1" ../miniapp-speedup.gp   -> miniapp-speedup-wide.tex
# MEANSTYLE, VALUES: see the bar-chart kit in style.gp.
load "../style.gp"
if (!exists("WIDE")) WIDE = 0
D = "../dat/miniapp-speedup.dat"
NOTE_IN = note_in(WIDE)
if (WIDE) {
    W = TEXTW ; H = 2.5 + NOTE_IN
    eval term(W, H)
    set output outname("miniapp-speedup-wide")
} else {
    W = COLW ; H = 2.95 + NOTE_IN + (MEANLONG ? -0.08 : 0)
    eval term(W, H)
    set output outname("miniapp-speedup")
}
MEAN_WIDE = WIDE

NS = 4 ; BW = (WIDE ? 0.2 : 0.22) ; BWM = (WIDE ? 0.24 : 0.26)
array SC[NS] = [C_VERA, C_VERA_SMT, C_AMD, C_INTEL]
array SE[NS] = [C_VERA, C_VERA, C_AMD, C_INTEL]
array SV[NS] = [0, 1, 0, 0]
array SL[NS] = [L_VERA, L_VERA_SMT, L_AMD, L_INTEL]

stats D u 0 nooutput ; NG = STATS_records
SUMGAP = (WIDE ? 0.35 : 0.3)
set xrange [-0.55:gx(NG-1)+(WIDE ? 0.8 : 0.7)]
set yrange [0:6 + (MEANSTYLE == 2 ? 0.6 : 0)]
set ytics 0, 1
if (LOGY) { eval log_axis(0.5, 8) }
eval SERIES_STYLES
set rmargin (WIDE ? 2.5 : 1.5)     # fixed: gnuplot cannot measure LaTeX tick labels
set ylabel 'Speedup vs Grace ($\times$)'
eval REFLINE
set arrow 91 from SEPX(0), graph 0 to SEPX(0), graph 1 nohead lc rgb C_GRID lw 1 back

if (WIDE) {
    set xtics scale 0
    set bmargin at screen bm_screen(0.50)
    unset key ; BARS_KEY = 0
    set tmargin at screen 1 - 0.30/H
    eval hkey_arrays(NS) ; HK_Y = 1 - 0.13/H
    eval KEYFILL
    eval hkey_setup
    LABCOL = 1
} else {
    # rotated app names; anchored below the axis line so they never cut it
    set xtics scale 0 rotate by 30 right offset 0.9,-0.25
    set bmargin at screen bm_screen(MEANLONG ? 0.56 : 0.62)
    # two-row key above the plot, drawn by gkey_setup (style.gp)
    unset key ; BARS_KEY = 0
    set tmargin at screen 1 - 0.44/H
    eval hkey_arrays(NS) ; HK_Y = 1 - 0.12/H
    eval KEYFILL
    eval gkey_setup
    LABCOL = NS + 2     # one-line short labels
}
eval mean_setup
# one column, rotated labels: a one-line summary label reads better than a
# stacked one
# one column: the app names are rotated, but the summary label is set upright
# in three lines, centred under the summary bars (a rotated block cannot be
# centred on its group)
if (!WIDE && MEANLONG) {
    MEANLAB = ""
    set label 85 tl3('Geo. mean', '(best of', 'SMT off/on)') at gx(NG-1), graph 0 center offset 0,-1.0 front
}
plot @BARS
