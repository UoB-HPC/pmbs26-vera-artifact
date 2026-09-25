#!/bin/sh
# Run every gnuplot figure script from inside a LaTeX compile (Overleaf).
# Called from the paper's preamble with shell escape, from the project root:
#     \ShellEscape{sh gnuplot/overleaf-build.sh}
# Needs only gnuplot (no Python): the gnuplot/dat/ tables must already be in
# the project (make them locally with python gnuplot/prep_data.py, then upload).
# A log goes to gnuplot/out/gnuplot.log (Overleaf: "Logs and output files" ->
# "Other logs and files").
cd "$(dirname "$0")" || exit 0
mkdir -p out
cd out || exit 0
LOG=gnuplot.log
{ echo "== $(date)"; gnuplot --version; } > "$LOG" 2>&1
for gp in ../*.gp; do
    name=$(basename "$gp" .gp)
    [ "$name" = style ] && continue
    # skip a figure whose data has not been uploaded yet
    case "$name" in
        c2c-heatmaps) [ -f ../dat/c2c-grace.csv ] || continue ;;
        *)            [ -f "../dat/$name.dat" ] || continue ;;
    esac
    echo "-- $name" >> "$LOG"
    gnuplot "$gp" >> "$LOG" 2>&1 || echo "   FAILED: $name" >> "$LOG"
done
# optional full-width versions of the NAS class-D and miniapp figures
for f in nas-speedup miniapp-speedup; do
    [ -f "../dat/$f.dat" ] && gnuplot -e "WIDE=1" "../$f.gp" >> "$LOG" 2>&1
done
exit 0
