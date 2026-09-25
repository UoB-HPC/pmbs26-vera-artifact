# Fig: NAS Parallel Benchmarks class D, whole-chip speedup vs whole-chip Grace,
# plus one summary group (geometric mean of the per-kernel best of SMT off/on).
# Data: dat/nas-speedup.dat  (kernel vera vera_smt turin gnr short_label)
#
# WIDE = 0 (default): one column.  WIDE = 1: full text width (figure*):
#     gnuplot -e "WIDE=1" ../nas-speedup.gp       -> nas-speedup-wide.tex
# MEANSTYLE, VALUES: see the bar-chart kit in style.gp.
load "../style.gp"
if (!exists("WIDE")) WIDE = 0
D = "../dat/nas-speedup.dat"
NOTE_IN = note_in(WIDE)
if (WIDE) {
    W = TEXTW ; H = 2.6 + NOTE_IN
    eval term(W, H)
    set output outname("nas-speedup-wide")
} else {
    W = COLW ; H = 2.75 + NOTE_IN
    eval term(W, H)
    set output outname("nas-speedup")
    VALUES = 0            # 40 bars of ~4pt: numbers only fit on the summary group
}
MEAN_WIDE = WIDE

NS = 4 ; BW = 0.2 ; BWM = (WIDE ? 0.24 : 0.46)
array SC[NS] = [C_VERA, C_VERA_SMT, C_AMD, C_INTEL]
array SE[NS] = [C_VERA, C_VERA, C_AMD, C_INTEL]
array SV[NS] = [0, 1, 0, 0]
array SL[NS] = [L_VERA, L_VERA_SMT, L_AMD, L_INTEL]
LABCOL = 1

stats D u 0 nooutput ; NG = STATS_records       # kernel groups + summary group
SUMGAP = (WIDE ? 0.35 : 1.1)
set xrange [-0.55:gx(NG-1)+(WIDE ? 0.8 : 0.85)]
set yrange [0:(VALUES ? 3.25 : 3.0) + (MEANSTYLE == 2 ? 0.35 : 0)]
set ytics 0, 0.5 format "%.1f"
if (LOGY) { eval log_axis(0.5, 4) }
eval SERIES_STYLES
set xtics scale 0
set rmargin (WIDE ? 2.5 : 2.8)   # fixed: gnuplot cannot measure LaTeX tick labels
set bmargin at screen bm_screen(MEANLONG && !WIDE ? 0.52 : 0.56)
# one column: kernel names are one line, so the x label sits right under them
# (the three-line summary label is to its right)
set xlabel 'NAS kernel (class D)' offset (WIDE ? 0 : -1.5),(WIDE ? -0.6 : 0.3)
set ylabel 'Speedup vs Grace ($\times$)'
if (WIDE) {
    # one-row key above the plot, drawn by hkey_setup (style.gp)
    unset key ; BARS_KEY = 0
    set tmargin at screen 1 - 0.30/H
    eval hkey_arrays(NS) ; HK_Y = 1 - 0.13/H
    eval KEYFILL
    eval hkey_setup
} else {
    unset key ; BARS_KEY = 0
    set tmargin at screen 1 - 0.44/H
    eval hkey_arrays(NS) ; HK_Y = 1 - 0.12/H
    eval KEYFILL
    eval gkey_setup
}
eval REFLINE
set arrow 91 from SEPX(0), graph 0 to SEPX(0), graph 1 nohead lc rgb C_GRID lw 1 back
eval mean_setup
plot @BARS
