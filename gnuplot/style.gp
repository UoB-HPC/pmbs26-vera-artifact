# =============================================================================
# style.gp - shared look for every paper figure. Load it first in each figure:
#     load "style.gp"
# Everything that is "style" lives here: sizes, fonts, colours, line styles.
# A figure script only says what to plot.
# =============================================================================

# --- Page geometry (IEEEtran conference, two columns) -------------------------
# \columnwidth = 252pt = 3.487in, \textwidth = 516pt = 7.14in.
# Figures are drawn at exactly these widths so LaTeX never rescales them:
# a 10pt label in the figure is then a 10pt label on the page.
COLW = 3.487          # inches, one column   -> \begin{figure}
TEXTW = 7.14          # inches, full width   -> \begin{figure*}

# --- Text ---------------------------------------------------------------------
# cairolatex hands every string to LaTeX, so text is set in the paper's own
# font. FONTPT only tells gnuplot how much room to leave for that text; keep it
# equal to the paper's body size (10pt).
FONTPT = 10
# Size of numbers printed on top of bars. \normalsize = body text.
# Use '\small' (9pt) only where bars are too narrow for 10pt.
VALSIZE = '\normalsize'

# Terminal. Call as:  eval term(width_in, height_in)
# "input" writes <name>.tex (text) + <name>.pdf (lines); \input the .tex.
# FIGFONT is put at the start of every figure: all figure text is set in
# Helvetica (TeX's Arial equivalent: Arial was drawn to Helvetica's widths).
# Every TeX system has it (package helvet / fonts phv), Overleaf included.
FIGFONT = '\\fontfamily{phv}\\selectfont'
term(w, h) = sprintf('set terminal cairolatex pdf input color colortext size %.3fin,%.3fin font ",%d" linewidth 1 dashlength 1 header "%s"', w, h, FONTPT, FIGFONT)

# Output file: set output outname("fig-name"). Passing -e "OUT='other'" writes
# other.tex / other.pdf instead (used to build design options side by side).
outname(n) = (exists("OUT") ? OUT : n) . ".tex"

# --- Architecture colours -----------------------------------------------------
# Vendor-anchored palette. NVIDIA chips share one green hue family and differ
# in lightness; AMD and Intel keep their brand hues. See README for the
# reasoning and the colour-blind checks.
C_GRACE    = "#0B5345"   # deep teal-green (NVIDIA family, dark = baseline)
C_VERA     = "#76B900"   # NVIDIA brand green (hero)
C_VERA_SMT = "#B4D873"   # C_VERA blended 45% towards white
C_AMD      = "#ED1C24"   # AMD brand red
C_INTEL    = "#0071C5"   # Intel classic blue
C_INTEL_SMT= "#8CBFE5"   # C_INTEL blended 55% towards white
C_REF      = "#777777"   # reference lines (y = 1, ideal scaling)
C_GRID     = "#B3B3B3"   # major grid lines: light, but visible in print
C_GRID_MIN = "#D9D9D9"   # minor grid lines

# --- Legend labels (one place to rename a chip everywhere) --------------------
L_GRACE     = 'Grace (72c)'
L_VERA      = 'Vera (88c)'
L_VERA_SMT  = 'Vera (88c), SMT on'
L_AMD       = 'EPYC 9R45 (96c)'
L_INTEL     = 'Xeon 6975P-C (96c)'
L_INTEL_SMT = 'Xeon 6975P-C (96c), SMT on'
# Short forms for one-row keys, where the variant sits next to its base chip
L_VERA_SMT_S  = 'Vera, SMT on'
L_INTEL_SMT_S = 'Xeon, SMT on'

# --- Line styles (line plots) -------------------------------------------------
# Each chip has its own colour AND marker AND (for variants) dash, so the plots
# still read in greyscale print.
PS = 0.45            # marker size; small because every data point is drawn
LW = 2.0
set style line 1 lc rgb C_GRACE     lw LW pt 7  ps PS dt 1   # circle
set style line 2 lc rgb C_VERA      lw LW pt 5  ps PS dt 1   # square
set style line 3 lc rgb C_VERA      lw LW pt 4  ps PS dt 2   # open square, dashed (SMT)
set style line 4 lc rgb C_AMD       lw LW pt 13 ps PS dt 1   # diamond
set style line 5 lc rgb C_INTEL     lw LW pt 9  ps PS dt 1   # triangle
set style line 6 lc rgb C_INTEL     lw LW pt 8  ps PS dt 2   # open triangle, dashed (SMT)
set style line 9 lc rgb C_REF       lw 1.2 dt 2             # reference / ideal

# Scaling plots with many core counts (Figs 7, 10): lines carry the data,
# markers only every PI-th point (for greyscale print). The gap between Vera
# SMT off and SMT on is shaded: green where SMT is faster, red where slower.
PI = 8
C_SMT_GAIN = "#B4D873" ; C_SMT_LOSS = "#F4A6A8"
set style line 11 lc rgb C_GRACE lw 1.6 pt 7  ps 0.5 pi PI
set style line 12 lc rgb C_VERA  lw 1.6 pt 5  ps 0.5 pi PI
set style line 13 lc rgb C_VERA  lw 1.6 pt 4  ps 0.5 pi PI dt 2
set style line 14 lc rgb C_AMD   lw 1.6 pt 13 ps 0.5 pi PI
set style line 15 lc rgb C_INTEL lw 1.6 pt 9  ps 0.5 pi PI
# BAND: prefix of a plot command; data file D, block index (i-1),
# column 3 = Vera SMT off, column 4 = Vera SMT on.
BAND = 'D index (i-1) u 1:4:3 w filledcurves above fc rgb C_SMT_GAIN fs solid 0.55 noborder notitle, ' . \
       'D index (i-1) u 1:4:3 w filledcurves below fc rgb C_SMT_LOSS fs solid 0.75 noborder notitle, '

# --- Axes, grid, key ----------------------------------------------------------
set border 3 lw 0.8                 # left + bottom only (matches the old style)
set tics nomirror out scale 0.6
# Grid. NB a bare "set grid xtics" in a figure script resets the line style to
# gnuplot's default (dotted, near-invisible), so figures use these macros:
#   @GRID_XY   major grid on x and y          @GRID_XY_MINOR  + minor grid lines
GRID_XY       = 'set grid xtics ytics nomxtics nomytics lt 1 lc rgb C_GRID lw 1.4 dt 1, lt 1 lc rgb C_GRID_MIN lw 1.0 dt 1 back'
GRID_XY_MINOR = 'set grid xtics ytics mxtics mytics lt 1 lc rgb C_GRID lw 1.4 dt 1, lt 1 lc rgb C_GRID_MIN lw 1.0 dt 1 back'
set grid ytics lt 1 lc rgb C_GRID lw 1.4 dt 1 back
set key noautotitle
set key samplen 2 spacing 1.0 width 0 noopaque nobox
set datafile missing "NaN"
# Plain tick numbers: the latex terminals default to "$%h$" (math mode), which
# would set them in the maths font instead of FIGFONT.
set format x "%g" ; set format y "%g" ; set format cb "%g"
set datafile commentschars "#"
set style fill solid 1.0 border -1

# --- Bar charts ---------------------------------------------------------------
# Grouped bars: group g (0-based row), series s of N, bar width BW.
# x position of bar s in group g:
bar_x(g, s, N, BW) = gx(g) + (s - (N - 1) / 2.0) * BW
# x position of group g. Speedup charts end with one summary group; SUMGAP > 0
# pushes it right, away from the benchmarks. Needs NG (group count).
SUMGAP = 0 ; NG = 0
gx(g) = g + (g >= NG - 1 ? SUMGAP : 0)
# x of the separator line between the benchmarks and the summary group
SEPX(dummy) = NG - 1.5 + 0.5*SUMGAP
BAR_BW = 0.2
# Bars fill only this share of their slot. The gap keeps a rotated 10pt number
# above one bar clear of a taller neighbour (a digit is ~7pt tall, so the slot
# must be wider than the bar by a few points).
BAR_FILL = 0.78
# Variant bars (SMT on) = light fill + hatch in the chip colour.
HATCH = 'fs transparent pattern 5 border'

# Speedup reference line at y = 1 (call after setting xrange).
REFLINE_LIN = 'set arrow 90 from graph 0, first 1 to graph 1, first 1 nohead lc rgb C_REF lw 1 dt 2 back'
# on the log axes (LOGY > 0) the bars grow from 1x, so 1x is a solid axis line
REFLINE_LOG = 'set arrow 90 from graph 0, first 1 to graph 1, first 1 nohead lc rgb "#444444" lw 1.2 dt 1 front'
REFLINE = (exists("LOGY") && LOGY > 0) ? REFLINE_LOG : REFLINE_LIN

# Number format for bar value labels
v2(x) = sprintf("%.2f", x)
# Offset for rotated value labels: a label rotated by 90 sits to the LEFT of its
# anchor (the glyphs rise leftwards from the baseline), so move it right by
# about half a digit height to centre it on the bar, and up off the bar top.
ROTOFF = "0.3,0.3"
v0(x) = sprintf("%.0f", x)

# --- Grouped-bar helpers --------------------------------------------------------
# Series tables: row = group, column 1 = group label, columns 2.. = series.
# Per-figure scripts fill these arrays, then use the plot fragments below:
#   array SC[n]  colour of series i          array SL[n]  legend label
#   array SV[n]  1 = variant (light fill + hatch in SE[i])
#   array SE[n]  edge/hatch colour of series i
# Plot a set of series with:
#   plot for [i=1:NS] D u (bar_x($0,i-1,NS,BW)):(column(i+1)) w boxes lc rgb SC[i] fs solid 1 border lc rgb SE[i] t SL[i], \
#        for [i=1:NS] D u (SV[i] ? bar_x($0,i-1,NS,BW) : NaN):(column(i+1)) w boxes lc rgb SE[i] fs transparent pattern 5 border lc rgb SE[i] notitle

# "Nice" tick step giving at most ~N intervals up to m (1, 2, 2.5, 5 x 10^k).
_p10(q) = 10.0**floor(log10(q))
_nice(q) = (q <= _p10(q)) ? _p10(q) : (q <= 2*_p10(q)) ? 2*_p10(q) : \
           (q <= 2.5*_p10(q)) ? 2.5*_p10(q) : (q <= 5*_p10(q)) ? 5*_p10(q) : 10*_p10(q)
nicestep(m, N) = _nice(1.0 * m / N)

# Tick label with k / M suffix, e.g. 250000 -> "250k", 1.2e6 -> "1.2M".
kfmt(v) = (v >= 1e6) ? sprintf("%gM", v/1e6) : (v >= 1e3) ? sprintf("%gk", v/1e3) : sprintf("%g", v)
# Set y tics 0..top in steps of st with kfmt labels:   eval ktics(top, st)
ktics(top, st) = sprintf('set ytics (%s)', kjoin(0, top, st))
kjoin(v, top, st) = (v > top + 0.5*st) ? '' : sprintf('"%s" %.10g%s', kfmt(v), v, (v + st > top + 0.5*st) ? '' : ', ') . kjoin(v + st, top, st)

# --- One-row key drawn by hand ------------------------------------------------
# gnuplot's own key gives every column the width of the longest entry, which
# wastes a lot of room in a single row. hkey_setup places entries one after
# another. Needs: W (figure width, in), arrays HK_T (titles) and HK_LS
# (line-style ids), HK_N entries, and HK_Y (screen y of the row).
# Text widths come from the Helvetica font metrics (FIGFONT), so
# the spacing is close to what LaTeX sets. Change HK_PT if the key text size changes.
HK_PT   = 10.0
HK_SAMP = 0.26       # sample line length, inches
HK_GAP  = 0.16       # gap between entries, inches
# Helvetica advance widths (1/1000 em) for ASCII 32..126, from phvr8a.afm
# (the name TIMES_W is kept so older scripts still work)
TIMES_W = "278 278 355 556 556 889 667 222 333 333 389 584 278 333 278 278 556 556 556 556 556 556 556 556 556 556 278 278 584 584 584 556 1015 667 667 722 722 667 611 778 722 278 500 667 556 833 722 778 667 778 722 667 611 722 667 944 667 667 611 278 278 278 469 556 222 556 556 500 556 556 278 556 556 222 222 500 222 833 556 556 556 556 333 500 278 556 500 722 500 500 500 334 260 334 584"
_ord(c, k) = (k > 126) ? 32 : (sprintf("%c", k) eq c) ? k : _ord(c, k + 1)
_cw(c) = word(TIMES_W, _ord(c, 32) - 31) / 1000.0 * HK_PT / 72.0
_strw(s) = (strlen(s) == 0) ? 0 : _cw(s[1:1]) + _strw(s[2:])
# Entry i is a line sample (HK_BOX[i] = 0, style HK_LS[i]) or a filled swatch
# (HK_BOX[i] = 1: fill HK_FC[i], edge HK_EC[i], hatched if HK_V[i] = 1).
# Arrays: HK_T, HK_BOX, HK_LS, HK_FC, HK_EC, HK_V (all size HK_N). HK_Y = screen
# y of the row; needs W and H (figure size in inches).
HK_BOXW = 0.20 ; HK_BOXH = 0.085
hk_s(i) = HK_BOX[i] ? HK_BOXW : HK_SAMP
hk_w(i) = hk_s(i) + 0.06 + _strw(HK_T[i])
hk_rect(n, i, x) = sprintf('set object %d rect from screen %g, screen %g to screen %g, screen %g front ', \
    n, x/W, HK_Y - HK_BOXH/2/H, (x + HK_BOXW)/W, HK_Y + HK_BOXH/2/H)
hkey_setup = 'HK_TOT = -HK_GAP ; do for [i=1:HK_N] { HK_TOT = HK_TOT + hk_w(i) + HK_GAP } ; \
  HK_X = (W - HK_TOT) / 2.0 ; \
  do for [i=1:HK_N] { \
    if (HK_BOX[i]) { \
      eval hk_rect(200+i, i, HK_X) . "fc rgb \"" . HK_FC[i] . "\" fs solid 1 border lc rgb \"" . HK_EC[i] . "\"" ; \
      if (HK_V[i]) { eval hk_rect(250+i, i, HK_X) . "fc rgb \"" . HK_EC[i] . "\" fs transparent pattern 5 border lc rgb \"" . HK_EC[i] . "\"" } \
    } else { \
      set arrow 200+i from screen HK_X/W, screen HK_Y to screen (HK_X+HK_SAMP)/W, screen HK_Y nohead ls HK_LS[i] front ; \
      set label 200+i "" at screen (HK_X+HK_SAMP/2)/W, screen HK_Y point ls HK_LS[i] front \
    } ; \
    set label 300+i HK_T[i] at screen (HK_X+hk_s(i)+0.06)/W, screen HK_Y left front ; \
    HK_X = HK_X + hk_w(i) + HK_GAP }'
# Declare the key arrays for n entries (defaults: line samples, no hatch).
hkey_arrays(n) = sprintf('HK_N = %d ; array HK_T[%d] ; array HK_BOX[%d] ; array HK_LS[%d] ; array HK_FC[%d] ; array HK_EC[%d] ; array HK_V[%d] ; do for [i=1:%d] { HK_BOX[i] = 0 ; HK_LS[i] = 1 ; HK_FC[i] = "#000000" ; HK_EC[i] = "#000000" ; HK_V[i] = 0 }', n, n, n, n, n, n, n, n)

# =============================================================================
# Speedup bar-chart kit (Figs 6, 9, 11)
# =============================================================================
# Table D: row = group, column 1 = long label, 2..NS+1 = series, NS+2 = short
# label; the LAST row is the summary group written by summary_rows() in
# prep_data.py: per chip, the geometric mean over all benchmarks of the faster
# of SMT off and SMT on (one value per chip, SMT-on columns NaN).
# A figure script sets D, NS, SC/SE/SV/SL, BW, NG, LABCOL, then:
#   MEANSTYLE  how the summary group says what it is (default 4)
#              1: two/three-line tick label  "Geo. mean (best of SMT off/on)"
#              2: shaded panel behind the group, header "Best of SMT off/on",
#                 tick label "Geo. mean"
#              3: tick label "Geo. mean*", footnote row under the x axis
#              4: the label of 1 on the shaded panel of 2, no header (chosen)
#   VALUES     1: a number on every bar;  0: numbers on the summary bars only
#   BWM        bar slot width inside the summary group (default BW)
# Missing values (NaN) leave no gap: the bars present in a group are centred.
if (!exists("MEANSTYLE")) MEANSTYLE = 4
# long (multi-line) summary label: styles 1 and 4
MEANLONG = (MEANSTYLE == 1 || MEANSTYLE == 4)
MEAN_SHADE = "#EDEDED"
if (!exists("VALUES")) VALUES = 0
tl2(a, b) = sprintf('\raisebox{0pt}[\ht\strutbox][\dp\strutbox]{\begin{tabular}[t]{@{}c@{}}%s\\%s\end{tabular}}', a, b)
# tl2b: same, but the LAST line sits on the anchor (block grows upwards)
tl2b(a, b) = sprintf('\begin{tabular}[b]{@{}c@{}}%s\\%s\end{tabular}', a, b)
# tl2c: plain two-line block, centred on its anchor (rotated axis labels)
tl2c(a, b) = sprintf('\begin{tabular}{@{}c@{}}%s\\%s\end{tabular}', a, b)
tl3(a, b, c) = sprintf('\raisebox{0pt}[\ht\strutbox][\dp\strutbox]{\begin{tabular}[t]{@{}c@{}}%s\\%s\\%s\end{tabular}}', a, b, c)
isv(j) = valid(j + 1) ? 1 : 0                       # series j present in this row?
rk(i) = (i <= 1) ? 0 : rk(i - 1) + isv(i - 1)        # rank of series i among present ones
ismean(d) = (column(0) == NG - 1)
bwg(d) = ismean(0) ? BWM : BW
bx(i) = gx(column(0)) + (rk(i) - (rk(NS + 1) - 1) / 2.0) * bwg(0)
bxw(d) = bwg(0) * BAR_FILL
NOTE_IN = 0.0                                          # MEANSTYLE 3 footnote row
note_in(wide) = (MEANSTYLE == 3 ? (wide ? 0.20 : 0.36) : 0)
# bottom margin in inches: x tick labels + x label (+ footnote row)
bm_screen(bm_in) = (bm_in + NOTE_IN) / H
# Call after NG, W, H, xrange: sets MEANLAB (tick label of the summary group),
# the style-2 panel and header, and the style-3 footnote.
#   MEAN_WIDE = 1 for full-width figures (longer label text fits)
mean_setup = ' \
  MX = gx(NG - 1) ; \
  if (MEANSTYLE == 4) { set object 80 rect from SEPX(0), graph 0 to graph 1, graph 1 fc rgb MEAN_SHADE fs solid 1 noborder behind } ; \
  if (MEANLONG) { MEANLAB = MEAN_WIDE ? tl2("Geo. mean", "(best of SMT off/on)") : tl3("Geo. mean", "(best of", "SMT off/on)") } ; \
  if (MEANSTYLE == 2) { MEANLAB = "Geo. mean" ; \
     set object 80 rect from SEPX(0), graph 0 to graph 1, graph 1 fc rgb MEAN_SHADE fs solid 1 noborder behind ; \
     set label 80 tl2("Best of", "SMT off/on") at MX, graph 0.95 center front ; \
  } ; \
  if (MEANSTYLE == 3) { MEANLAB = "Geo. mean$^{*}$" ; \
     set label 81 (MEAN_WIDE ? NOTE_TEXT : NOTE_TEXT2) at screen 0.5, screen ((NOTE_IN - 0.10) / H) center front }'
NOTE_TEXT = '$^{*}$Geometric mean of the faster of SMT off and SMT on for each benchmark'
NOTE_TEXT2 = tl2('$^{*}$Geometric mean of the faster of', 'SMT off and SMT on for each benchmark')
tick(d) = ismean(0) ? MEANLAB : strcol(LABCOL)
# The plot command (use as:  plot @BARS). Legend titles come from SL[] when
# BARS_KEY = 1 (gnuplot key); 0 when the figure draws its own key row.
BARS = 'D u (gx($0)):(NaN):xtic(tick(0)) notitle, \
  for [i=1:NS] D u (bx(i)):(column(i+1)):(bxw(0)) w boxes lc rgb SC[i] fs solid 1 border lc rgb SE[i] t (BARS_KEY ? SL[i] : ""), \
  for [i=1:NS] D u (SV[i] ? bx(i) : NaN):(column(i+1)):(bxw(0)) w boxes lc rgb SE[i] fs transparent pattern 5 border lc rgb SE[i] notitle, \
  for [i=1:NS] D u ((VALUES || ismean(0)) ? bx(i) : NaN):(column(i+1)):(v2(column(i+1))) w labels rotate by 90 left offset 0.3,0.3 notitle'

# --- Two-row key drawn by hand (one-column figures) ---------------------------
# Same arrays as hkey_setup (HK_T, HK_BOX, HK_LS, HK_FC, HK_EC, HK_V, HK_N,
# even N), filled column by column: entries 1,2 = column 1, 3,4 = column 2...
# HK_Y = screen y of the upper row; rows are HK_DY inches apart.
HK_DY = 0.17
_mx(a, b) = (a > b) ? a : b
gk_rect(n, i, x, y) = sprintf('set object %d rect from screen %g, screen %g to screen %g, screen %g front ', \
    n, x/W, y - HK_BOXH/2/H, (x + HK_BOXW)/W, y + HK_BOXH/2/H)
gkey_setup = 'GK_NC = HK_N / 2 ; GK_TOT = -HK_GAP ; \
  do for [c=1:GK_NC] { GK_TOT = GK_TOT + _mx(hk_w(2*c-1), hk_w(2*c)) + HK_GAP } ; \
  GK_X = (W - GK_TOT) / 2.0 ; \
  do for [c=1:GK_NC] { \
    do for [r=0:1] { i = 2*c - 1 + r ; y = HK_Y - r*HK_DY/H ; \
      if (HK_BOX[i]) { \
        eval gk_rect(200+i, i, GK_X, y) . "fc rgb \"" . HK_FC[i] . "\" fs solid 1 border lc rgb \"" . HK_EC[i] . "\"" ; \
        if (HK_V[i]) { eval gk_rect(250+i, i, GK_X, y) . "fc rgb \"" . HK_EC[i] . "\" fs transparent pattern 5 border lc rgb \"" . HK_EC[i] . "\"" } \
      } else { \
        set arrow 200+i from screen GK_X/W, screen y to screen (GK_X+HK_SAMP)/W, screen y nohead ls HK_LS[i] front ; \
        set label 200+i "" at screen (GK_X+HK_SAMP/2)/W, screen y point ls HK_LS[i] front \
      } ; \
      set label 300+i HK_T[i] at screen (GK_X+hk_s(i)+0.06)/W, screen y left front } ; \
    GK_X = GK_X + _mx(hk_w(2*c-1), hk_w(2*c)) + HK_GAP }'

# --- Log-scale speedup axes (global switch for every speedup chart) ----------
# LOGY = 0: linear axis from 0, bars from 0
#        1: (default) log2 axis, so 2x and 0.5x sit the same distance from 1x; bars start
#           at 1x (up = faster than the baseline, down = slower)
#        2: log2 axis, lollipops: a stem from 1x to a dot at the value (open
#           dot = SMT on)
if (!exists("LOGY")) LOGY = 1      # chosen: log2 axis, bars from 1x
# ticks on the log axis (same set in every figure)
# Labels only at powers of two; dashed grid lines (unlabelled minor ticks) at
# 3 x 2^k (0.75, 1.5, 3, 6), which sit between each pair of labelled lines.
LOGTICS = 'unset mytics ; set ytics ("0.5" 0.5, "1" 1, "2" 2, "4" 4, "8" 8) ; set ytics add ("" 0.75 1, "" 1.5 1, "" 3 1, "" 6 1) ; set grid ytics mytics lt 1 lc rgb C_GRID lw 1.4 dt 1, lt 1 lc rgb C_GRID lw 1.0 dt (3,3) back'
# call as: eval log_axis(lo, hi)  (after the linear yrange/ytics lines)
# (the top is padded by 0.1%: a tick exactly on the range end is dropped)
log_axis(lo, hi) = sprintf('set logscale y 2 ; set yrange [%g:%g] ; %s', lo, hi*1.001, LOGTICS)
# line styles 31.. for lollipops and their key samples (needs NS, SE, SV)
SERIES_STYLES = 'do for [i=1:NS] { set style line 30+i lc rgb SE[i] lw 2.2 pt (SV[i] ? 6 : 7) ps 0.85 }'
# key row entries for the speedup charts (hkey/gkey arrays)
KEYFILL = 'do for [i=1:NS] { HK_T[i] = SL[i] ; HK_BOX[i] = (LOGY != 2) ; HK_LS[i] = 30+i ; HK_FC[i] = SC[i] ; HK_EC[i] = SE[i] ; HK_V[i] = SV[i] }'
showv(i) = (VALUES || ismean(0))
BARS_LOG = 'D u (gx($0)):(NaN):xtic(tick(0)) notitle, \
  for [i=1:NS] D u (bx(i)):(column(i+1)):(bx(i)-bxw(0)/2):(bx(i)+bxw(0)/2):(1):(column(i+1)) w boxxyerror lc rgb SC[i] fs solid 1 border lc rgb SE[i] t (BARS_KEY ? SL[i] : ""), \
  for [i=1:NS] D u (SV[i] ? bx(i) : NaN):(column(i+1)):(bx(i)-bxw(0)/2):(bx(i)+bxw(0)/2):(1):(column(i+1)) w boxxyerror lc rgb SE[i] fs transparent pattern 5 border lc rgb SE[i] notitle, \
  for [i=1:NS] D u ((showv(i) && column(i+1) >= 1) ? bx(i) : NaN):(column(i+1)):(v2(column(i+1))) w labels rotate by 90 left offset 0.3,0.3 notitle, \
  for [i=1:NS] D u ((showv(i) && column(i+1) < 1) ? bx(i) : NaN):(column(i+1)):(v2(column(i+1))) w labels rotate by 90 right offset 0.3,-0.3 notitle'
BARS_LOLLI = 'D u (gx($0)):(NaN):xtic(tick(0)) notitle, \
  for [i=1:NS] D u (bx(i)):(1):(0):(column(i+1) - 1) w vectors nohead ls 30+i notitle, \
  for [i=1:NS] D u (bx(i)):(column(i+1)) w p ls 30+i t (BARS_KEY ? SL[i] : ""), \
  for [i=1:NS] D u ((showv(i) && column(i+1) >= 1) ? bx(i) : NaN):(column(i+1)):(v2(column(i+1))) w labels rotate by 90 left offset 0.3,0.7 notitle, \
  for [i=1:NS] D u ((showv(i) && column(i+1) < 1) ? bx(i) : NaN):(column(i+1)):(v2(column(i+1))) w labels rotate by 90 right offset 0.3,-0.7 notitle'
if (LOGY == 1) { BARS = BARS_LOG }
if (LOGY == 2) { BARS = BARS_LOLLI }
# (REFLINE was chosen above, before LOGY had its default: choose it again)
REFLINE = (LOGY > 0) ? REFLINE_LOG : REFLINE_LIN
