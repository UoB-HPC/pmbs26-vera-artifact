# Fig: scientific applications, whole-chip speedup vs whole-chip Grace, plus
# one summary group (geometric mean of the per-app best of SMT off/on).
# Full text width (figure*).   Data: dat/apps-speedup.dat
#   columns: app vera vera_smt turin gnr gnr_smt short_label   (NaN = not run)
# Missing bars leave no gap (bar-chart kit, style.gp). OpenFOAM has no SMT-on
# runs: a note above its group says why.
# MEANSTYLE, VALUES: see the bar-chart kit in style.gp.
load "../style.gp"
W = TEXTW
NOTE_IN = note_in(1)
H = 2.75 + NOTE_IN
eval term(W, H)
set output outname("apps-speedup")
D = "../dat/apps-speedup.dat"
MEAN_WIDE = 1

NS = 5 ; BW = 0.16 ; BWM = 0.22
array SC[NS] = [C_VERA, C_VERA_SMT, C_AMD, C_INTEL, C_INTEL_SMT]
array SE[NS] = [C_VERA, C_VERA, C_AMD, C_INTEL, C_INTEL]
array SV[NS] = [0, 1, 0, 0, 1]
array SL[NS] = [L_VERA, L_VERA_SMT_S, L_AMD, L_INTEL, L_INTEL_SMT_S]
LABCOL = 1

stats D u 0 nooutput ; NG = STATS_records
SUMGAP = 0.35
set xrange [-0.5:gx(NG-1)+0.8]
set yrange [0:4.5 + (MEANSTYLE == 2 ? 0.3 : 0)]
set ytics 0, 0.5 format "%.1f"
if (LOGY) { eval log_axis(0.5, 4) }
eval SERIES_STYLES
set xtics scale 0
set rmargin 2.5     # fixed: gnuplot cannot measure LaTeX tick labels
set ylabel 'Speedup vs Grace ($\times$)'
unset key ; BARS_KEY = 0
set tmargin at screen 1 - 0.30/H
eval hkey_arrays(NS) ; HK_Y = 1 - 0.13/H
eval KEYFILL
eval hkey_setup
set bmargin at screen bm_screen(0.50)
eval REFLINE
set arrow 91 from SEPX(0), graph 0 to SEPX(0), graph 1 nohead lc rgb C_GRID lw 1 back

# OpenFOAM has no SMT-on run (pure MPI code). Default: an asterisk on its
# label (prep_data.py), explained in the caption. OFNOTE = 1 instead writes
# a note above the group.
if (!exists("OFNOTE")) OFNOTE = 0
stats D u (strcol(NS+2) eq "OpenFOAM" ? $0 : NaN) nooutput
if (OFNOTE && STATS_records > 0 && exists("STATS_min")) {
    IOF = int(STATS_min) ; YOF = 0
    do for [c=2:NS+1] {
        undefine STATS_*
        stats D every ::IOF::IOF u (column(c)) nooutput
        if (exists("STATS_max")) { if (STATS_max > YOF) { YOF = STATS_max } }
    }
    set label 70 tl2b('Native threading', 'support unavailable') \
        at gx(IOF), first YOF + (VALUES ? 0.66 : 0.08) center offset 0,1.15 front
}
eval mean_setup
plot @BARS
