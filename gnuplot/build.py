"""Build every paper figure with gnuplot.

    python gnuplot/build.py              # prep data + all figures
    python gnuplot/build.py nas-smt      # just one (or several) figures
    python gnuplot/build.py --preview    # also compile preview/preview.pdf

Steps:
  1. prep_data.py turns data/ and results/c2c/ into gnuplot/dat/*.dat
  2. gnuplot runs each <figure>.gp inside gnuplot/out/, writing
     <figure>.tex (all text) + <figure>.pdf (lines, bars, images)
  3. (--preview) pdflatex builds preview/preview.pdf: every figure at its real
     size on an IEEEtran page, next to 10pt body text

A figure whose .dat input is missing is skipped with a message; it builds as
soon as the data exists. gnuplot is found on PATH, or set GNUPLOT=<path>.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
DAT = HERE / "dat"

# figure script -> the dat files it needs (paper figure number for reference)
FIGURES = {
    "stream-scaling":  ["stream-scaling"],                        # Fig 2
    "tlb-latency":     ["tlb-latency", "tlb-cache"],              # Fig 3
    "c2c-heatmaps":    ["c2c-grace.csv", "c2c-vera.csv", "c2c-turin-9r45.csv", "c2c-gnr.csv"],  # Fig 4
    "c2c-stats":       ["c2c-stats"],                             # Fig 5
    "nas-speedup":     ["nas-speedup"],                           # Fig 6 (one column)
    "nas-speedup-wide": ["nas-speedup"],                          # Fig 6 (full width option)
    "nas-scaling":     ["nas-scaling"],                           # Fig 7
    "nas-smt":         ["nas-smt"],                               # Fig 8
    "miniapp-speedup": ["miniapp-speedup"],                       # Fig 9 (one column)
    "miniapp-speedup-wide": ["miniapp-speedup"],                  # Fig 9 (full width option)
    "miniapp-scaling": ["miniapp-scaling"],                       # Fig 10
    "apps-speedup":    ["apps-speedup"],                          # Fig 11
}


# figures built from another figure's script with extra gnuplot arguments
VARIANTS = {"nas-speedup-wide": ("nas-speedup", ["-e", "WIDE=1"]),
            "miniapp-speedup-wide": ("miniapp-speedup", ["-e", "WIDE=1"])}

# expected warnings: empty series (chip with no data yet), NaN diagonal of c2c
QUIET = ("Skipping data file", "No valid data points", "matrix contains missing")


def find_gnuplot() -> str:
    exe = os.environ.get("GNUPLOT") or shutil.which("gnuplot")
    if not exe:
        sys.exit("gnuplot not found: install it (http://www.gnuplot.info) "
                 "or set GNUPLOT=<path to gnuplot executable>")
    return exe


def main(argv: list[str]) -> int:
    preview = "--preview" in argv
    wanted = [a for a in argv if not a.startswith("--")] or list(FIGURES)
    unknown = [w for w in wanted if w not in FIGURES]
    if unknown:
        sys.exit(f"unknown figure(s): {', '.join(unknown)}; choose from {', '.join(FIGURES)}")

    subprocess.run([sys.executable, str(HERE / "prep_data.py")], check=True)
    gp = find_gnuplot()
    OUT.mkdir(exist_ok=True)

    built, skipped, failed = [], [], []
    for fig in wanted:
        missing = [d for d in FIGURES[fig]
                   if not (DAT / (d if "." in d else f"{d}.dat")).exists()]
        if missing:
            skipped.append(f"{fig} (needs dat/{', dat/'.join(missing)})")
            continue
        script, extra = VARIANTS.get(fig, (fig, []))
        r = subprocess.run([gp, *extra, str(HERE / f"{script}.gp")], cwd=OUT,
                           capture_output=True, text=True)
        # gnuplot warns about empty series (e.g. a chip with no data yet); show
        # those once, but only real errors fail the figure
        msgs = [l for l in r.stderr.splitlines() if l.strip()
                and not any(w in l for w in QUIET)]
        for l in msgs:
            print(f"  [{fig}] {l}")
        (built if r.returncode == 0 else failed).append(fig)

    print(f"\nbuilt   {len(built)}: {', '.join(built) or '-'}")
    if skipped:
        print(f"skipped {len(skipped)}:\n  " + "\n  ".join(skipped))
    if failed:
        print(f"FAILED  {len(failed)}: {', '.join(failed)}")

    if preview:
        latex = shutil.which("pdflatex")
        if not latex:
            print("--preview: pdflatex not found, skipping")
        else:
            for _ in range(2):   # twice so figure numbers settle
                subprocess.run([latex, "-interaction=nonstopmode", "preview.tex"],
                               cwd=HERE / "preview", capture_output=True)
            print(f"preview -> {HERE / 'preview' / 'preview.pdf'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
