# Paper figures (gnuplot)

These scripts draw Figs. 2-11 of the paper from `data/` and `results/c2c/`.

```
build.py          run this: prep_data.py, then gnuplot on each figure script
prep_data.py      data/ + results/c2c/ -> dat/*.dat (speedups, geometric means, filtering)
make_apps_csv.py  results/applications/ -> data/applications/apps.csv
style.gp          shared styling: page widths, colours, labels, line styles
<figure>.gp       one script per figure
overleaf-build.sh runs the figure scripts inside a LaTeX compile (shell escape)
dat/, out/        generated
```

## Build

Needs Python 3 with pandas and NumPy, and gnuplot >= 5.4 with the
`cairolatex` terminal. From the artifact root:

```bash
python3 scripts/run_parsers.py      # if data/ is not there yet
python3 gnuplot/build.py            # all figures -> gnuplot/out/<name>.tex + <name>.pdf
python3 gnuplot/build.py nas-smt    # one figure
python3 gnuplot/build.py --preview  # + preview/preview.pdf (needs pdflatex, IEEEtran)
```

Each figure is a `.tex` file (all text, set by LaTeX in the paper's font)
plus a `.pdf` (lines, bars, images). Include it unscaled with
`\input{<name>.tex}`; it is drawn at the IEEEtran column width (3.487 in)
or text width (7.14 in).

## Figures

| paper | output | script | width |
|---|---|---|---|
| Fig. 2 | `stream-scaling` | `stream-scaling.gp` | column |
| Fig. 3 | `tlb-latency` | `tlb-latency.gp` | column |
| Fig. 4 | `c2c-heatmaps` | `c2c-heatmaps.gp` | column |
| Fig. 5 | `c2c-stats` | `c2c-stats.gp` | column |
| Fig. 6 | `nas-speedup-wide` | `nas-speedup.gp` with `-e "WIDE=1"` | text |
| Fig. 7 | `nas-scaling` | `nas-scaling.gp` | text |
| Fig. 8 | `nas-smt` | `nas-smt.gp` | column |
| Fig. 9 | `miniapp-speedup` | `miniapp-speedup.gp` | column |
| Fig. 10 | `miniapp-scaling` | `miniapp-scaling.gp` | column |
| Fig. 11 | `apps-speedup` | `apps-speedup.gp` | text |

`build.py` also writes `nas-speedup` (one column) and `miniapp-speedup-wide`
(text width); these are not in the paper.

## Derived quantities (all in `prep_data.py`)

- Speedup = figure of merit relative to Grace: Mop/s ratio for NAS; time
  ratio (Grace / platform) for miniapps and applications; for rate metrics
  (ns/day) platform / Grace.
- Summary group on the speedup charts: for each benchmark take the faster
  of SMT off and SMT on, then the geometric mean over benchmarks. Chips
  without SMT runs use their SMT-off value.
- Cache boundaries in Fig. 3 come from `CACHE` in `prep_data.py`
  (L1d, L2, L3 per chip).
- Core-to-core: the matrices are read unchanged. The 97th row/column of the
  gnr and turin-9r45 matrices (one CPU past socket 0) is cropped.
- `prep_data.py` prints "missing data/mt-comparison/..." — this optional
  input is not part of the artifact and is not used, because
  `data/miniapps/scaling.csv` already contains the Vera SMT-on sweeps.
