"""Turn the repo's parsed CSVs into small gnuplot-ready tables.

gnuplot is good at drawing but awkward at filtering, joining and taking
geometric means. This script does that arithmetic once, in pandas, and writes
plain whitespace-separated tables into gnuplot/dat/. Every gnuplot script then
only reads columns.

Run from the repo root (build.py does this for you):
    python gnuplot/prep_data.py

Missing inputs are skipped with a warning. A figure whose table is missing is
skipped by build.py. When the newer data lands in data/ (or results/c2c/), just
re-run build.py; no script edits are needed.

Conventions in the output tables:
  * one row per x value / bar group, one column per series
  * missing values are written as NaN (gnuplot: set datafile missing "NaN")
  * text columns are double-quoted so they may contain spaces
"""

from __future__ import annotations

import csv
import math
import shutil
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
RESULTS = ROOT / "results"
OUT = Path(__file__).resolve().parent / "dat"

# Series order used by every figure. Must match the column order the .gp files
# expect (see the header line written into each .dat file).
ARCHES = ["grace", "vera", "turin-9r45", "gnr"]
CORES = {"grace": 72, "vera": 88, "turin-9r45": 96, "gnr": 96}

NAS_KERNELS = ["BT", "CG", "EP", "FT", "IS", "LU", "MG", "SP", "UA"]
MINIAPPS = [("cloverleaf", "CloverLeaf", "bm32_short"),
            ("minibude", "miniBUDE", "bm1"),
            ("tealeaf", "TeaLeaf", "bm_5e_2"),
            ("neutral", "Neutral", "stream")]

written: list[str] = []

# Group labels are LaTeX (cairolatex terminal): two-line labels use \shortstack.
# \twoline keeps the first line level with one-line labels (it reports the
# height of one line and hangs the second line below).
TWOLINE = (r"\raisebox{0pt}[\ht\strutbox][\dp\strutbox]"
           r"{\begin{tabular}[t]{@{}c@{}}%s\\%s\end{tabular}}")
GM_LABEL = TWOLINE % ("Geometric", "mean")
BEST_LABEL = TWOLINE % ("Best of", "SMT off/on")
# short forms for one-column figures, where a group is only ~20-35pt wide
GM_SHORT = TWOLINE % ("Geo.", "mean")
BEST_SHORT = TWOLINE % ("Best", "on/off")


def stack(name: str, case: str, nudge_pt: float = 0) -> str:
    """Two-line x label: name over (case), with LaTeX-escaped underscores.

    nudge_pt > 0 shifts the label left by nudge_pt/2 (a trailing \\kern widens
    the centred box on the right). Used where two neighbouring 10pt labels in a
    one-column figure would otherwise touch.
    """
    s = TWOLINE % (name, "(" + case.replace("_", r"\_") + ")")
    return s + (rf"\kern{nudge_pt:g}pt" if nudge_pt else "")


def warn(msg: str) -> None:
    print(f"  [prep] warning: {msg}")


def gmean(values) -> float:
    v = [x for x in values if x is not None and np.isfinite(x) and x > 0]
    return math.exp(sum(math.log(x) for x in v) / len(v)) if v else float("nan")


def summary_rows(rows, variant_of, label=None, short=None):
    """The one summary group at the end of every speedup bar chart.

    rows: [label, s1, s2, ..., short_label]; variant_of maps the index of an
    SMT-on series to the index of its SMT-off series (0-based over s1..sn).

    Per chip: for each benchmark take the faster of SMT off and SMT on, then
    the geometric mean over all benchmarks. One value per chip, written in its
    SMT-off column; the SMT-on column is NaN (the figure closes the gap).
    Chips with no SMT runs (EPYC here) get the plain geometric mean. Where one
    benchmark has no SMT-on run (OpenFOAM), its SMT-off value is used.
    On Vera and Xeon SMT is chosen per job by launching one or two threads per
    core, with no reboot, so this is what a user who picks the better setting
    per code gets. The group label is set in the .gp script (MEANSTYLE).
    """
    n = len(rows[0]) - 2
    base_of = dict(variant_of)                      # smt index -> base index
    smt_of = {b: v for v, b in base_of.items()}
    best = []
    for i in range(n):
        if i in base_of:
            best.append(float("nan"))
        elif i in smt_of:
            j = smt_of[i]
            best.append(gmean(max(r[i + 1], r[j + 1]) if np.isfinite(r[j + 1]) else r[i + 1]
                              for r in rows))
        else:
            best.append(gmean(r[i + 1] for r in rows))
    return [[label or GM_LABEL] + best + [short or GM_SHORT]]


def fmt(v) -> str:
    if isinstance(v, str):
        # gnuplot reads backslash escapes inside double-quoted data strings,
        # so LaTeX backslashes are doubled here.
        return '"' + v.replace("\\", "\\\\") + '"'
    if v is None or (isinstance(v, float) and not np.isfinite(v)):
        return "NaN"
    return f"{v:.6g}"


def write(name: str, header: list[str], rows: list[list], blocks=None) -> None:
    """Write one table. `blocks` (list of row-lists) writes gnuplot data blocks
    separated by two blank lines, addressed in gnuplot with `index N`."""
    OUT.mkdir(exist_ok=True)
    path = OUT / f"{name}.dat"
    with path.open("w", newline="\n") as fh:
        fh.write("# " + "  ".join(header) + "\n")
        for bi, block in enumerate(blocks if blocks is not None else [rows]):
            if bi:
                fh.write("\n\n")
            for r in block:
                fh.write(" ".join(fmt(v) for v in r) + "\n")
    written.append(name)
    print(f"  [prep] wrote gnuplot/dat/{name}.dat")


def read_csv(rel: str) -> pd.DataFrame | None:
    p = DATA / rel
    if not p.exists():
        warn(f"missing data/{rel}")
        return None
    return pd.read_csv(p)


# --- Fig: STREAM scaling (round-robin placement) ----------------------------

def stream() -> None:
    df = read_csv("stream/scaling.csv")
    if df is None:
        return
    df = df[df["placement"] == "round-robin"]
    blocks = []
    for a in ARCHES:
        d = df[df["arch"] == a].sort_values("cores")
        if d.empty:
            warn(f"stream: no round-robin data for {a}")
        blocks.append([[int(c), float(b)] for c, b in zip(d["cores"], d["triad_gbps"])]
                      or [[float("nan"), float("nan")]])
    write("stream-scaling", ["cores", "triad_GBps", "(index 0..3 =", *ARCHES, ")"],
          [], blocks)


# --- Fig: test-tlb random-access latency (hugepages) -------------------------

# Cache sizes in bytes (L1d, L2, L3) for the boundary markers.
#   Grace / Vera: vendor documentation (Vera L3 = 164 MB, decimal, as measured).
#   EPYC 9R45 (Zen 5): L3 is 32 MiB per 8-core CCD - what one thread can use.
#   Xeon 6975P-C: 96-core Granite Rapids parts list 480 MB of L3 - confirm.
CACHE = {
    "grace":      (64 << 10, 1 << 20, 114 << 20),
    "vera":     (96 << 10, 2 << 20, 164_000_000),
    "turin-9r45": (48 << 10, 1 << 20, 32 << 20),
    "gnr":        (48 << 10, 2 << 20, 480_000_000),
}

def tlb() -> None:
    df = read_csv("test-tlb/latencies.csv")
    if df is None:
        return
    df = df[df["pattern"] == "rand-huge"]
    sizes = sorted(df["size_bytes"].unique())
    rows = []
    for s in sizes:
        row = [int(s), df[df["size_bytes"] == s]["size_label"].iloc[0]]
        for a in ARCHES:
            v = df[(df["arch"] == a) & (df["size_bytes"] == s)]["latency_ns"]
            row.append(float(v.iloc[0]) if len(v) else float("nan"))
        rows.append(row)
    write("tlb-latency", ["bytes", "label", *ARCHES], rows)

    # Cache boundaries: one row per (chip, level) with the curve's latency at
    # that size (log-log interpolation), so the figure can pin each marker to
    # its own curve.
    out = []
    for ai, a in enumerate(ARCHES):
        d = df[df["arch"] == a].sort_values("size_bytes")
        if d.empty:
            continue
        lx, ly = np.log(d["size_bytes"].to_numpy(float)), np.log(d["latency_ns"].to_numpy(float))
        for level, size in zip(("L1d", "L2", "L3"), CACHE[a]):
            out.append([ai, level, size, float(np.exp(np.interp(np.log(size), lx, ly)))])
    # Column 5 = number of chips with this exact size, column 6 = x position
    # (the true size). A shared size is drawn as ONE line (see tlb-dash).
    from collections import Counter
    count = Counter(r[2] for r in out)
    for r in out:
        r += [count[r[2]], r[2]]
    write("tlb-cache", ["chip_index(0=grace,1=vera,2=turin,3=gnr)", "level", "bytes",
                        "latency_ns", "n_sharing", "x"], out)

    # Dash segments for every boundary line. A size shared by two chips is one
    # line whose dashes alternate between their colours; a lone chip's line is
    # dash, gap, dash in its colour.
    # index 0: label strip, y in strip rows (chip c's label sits at 3.5 - c;
    #          the line runs down to 0).  index 1: latency plot, y as a fraction
    #          t of the plot height (0 = bottom); the script maps t to latency.
    # Columns: x  y0  y1  chip.   DASH_IN = dash period on the page.
    DASH_IN, STRIP_ROW_IN, PLOT_IN = 0.075, 0.155, 1.95   # match tlb-latency.gp
    groups = {}
    for r in out:
        groups.setdefault(r[2], []).append(r[0])
    strip, plot = [], []

    def dashes(x, top, bottom, period, chips, dest):
        """Cut top..bottom into dashes; alternate chips, or dash/gap for one."""
        k, y = 0, top
        while y > bottom + 1e-9:
            if len(chips) == 1:
                dest.append([x, y, max(y - 0.57 * period, bottom), chips[0]])   # 4 on, 3 off
                y -= period
            else:
                y1 = max(y - period / len(chips), bottom)
                dest.append([x, y, y1, chips[k % len(chips)]])
                y, k = y1, k + 1

    for x, chips in groups.items():
        chips = sorted(chips)                               # top strip row first
        rows_ = [3.5 - c for c in chips] + [0.0]
        for m in range(len(chips)):                         # between label rows
            dashes(x, rows_[m], rows_[m + 1], DASH_IN / STRIP_ROW_IN, chips[:m + 1], strip)
        dashes(x, 1.0, 0.0, DASH_IN / PLOT_IN, chips, plot)
    write("tlb-dash", ["x", "y0", "y1", "chip", "(index 0 = strip rows, 1 = plot fraction)"],
          [], [strip, plot])


# --- Figs: core-to-core heatmaps + distribution bars -------------------------

C2C_FILE: dict[str, str] = {}   # one matrix per platform: core-to-core-latency.csv


def read_c2c(arch: str) -> np.ndarray | None:
    p = RESULTS / "c2c" / arch / C2C_FILE.get(arch, "core-to-core-latency.csv")
    if not p.exists():
        warn(f"missing {p.relative_to(ROOT)}")
        return None
    rows = []
    with p.open(newline="") as fh:
        for r in csv.reader(fh):
            rows.append([float(c) for c in r if c.strip()])
    n = len(rows)
    m = np.full((n, n), np.nan)
    for i, vals in enumerate(rows):
        for j, v in enumerate(vals):
            m[i, j] = m[j, i] = v
    if n > CORES[arch]:     # x86 sweeps include one non-existent core
        warn(f"c2c {arch}: {n}x{n} matrix truncated to {CORES[arch]} cores")
        m = m[:CORES[arch], :CORES[arch]]
    return m


def c2c() -> None:
    stats = {}
    for a in ARCHES:
        m = read_c2c(a)
        if m is None:
            continue
        # The heatmap reads the raw lower-triangular CSV itself (gnuplot's
        # "matrix" format), so it is copied unchanged: this keeps every input
        # the figures need inside gnuplot/dat/ (handy for Overleaf).
        OUT.mkdir(exist_ok=True)
        src = RESULTS / "c2c" / a / C2C_FILE.get(a, "core-to-core-latency.csv")
        shutil.copyfile(src, OUT / f"c2c-{a}.csv")
        written.append(f"c2c-{a}")
        print(f"  [prep] copied {src.relative_to(ROOT)} -> gnuplot/dat/c2c-{a}.csv")
        v = m[np.tril(np.ones_like(m, dtype=bool), k=-1)]
        v = v[np.isfinite(v)]
        stats[a] = [np.percentile(v, 5), v.mean(), np.median(v), np.percentile(v, 95)]
    if stats:
        names = [TWOLINE % ("5th", "percentile"), "Mean", "Median",
                 TWOLINE % ("95th", "percentile")]
        rows = [[n] + [stats.get(a, [np.nan] * 4)[i] for a in ARCHES]
                for i, n in enumerate(names)]
        write("c2c-stats", ["stat", *ARCHES], rows)


# --- Figs: NAS class D speedup, SMT effect, class B scaling ------------------

def nas() -> None:
    df = read_csv("npb/nas-D.csv")
    if df is not None:
        def mops(a, variant, k):
            v = df[(df["arch"] == a) & (df["variant"] == variant) & (df["kernel"] == k)]["mops"]
            return float(v.iloc[0]) if len(v) else float("nan")

        series = [("vera", "base"), ("vera", "smt"), ("turin-9r45", "base"), ("gnr", "base")]
        kernels = [k for k in NAS_KERNELS if k in set(df["kernel"])]
        absent = [k for k in NAS_KERNELS if k not in kernels]
        if absent:
            warn(f"nas-D.csv has no {', '.join(absent)} - those groups are left out")
        rows = []
        for k in kernels:
            base = mops("grace", "base", k)
            rows.append([k] + [mops(a, v, k) / base for a, v in series] + [k])
        # In the one-column figure a group is ~19pt wide: the two short summary
        # labels are nudged right (into the right margin) so they do not touch.
        rows += summary_rows(rows, {1: 0})
        write("nas-speedup", ["kernel", "vera", "vera_smt", "turin", "gnr", "short_label"], rows)

        smt = [[k, mops("vera", "smt", k) / mops("vera", "base", k)] for k in kernels]
        write("nas-smt", ["kernel", "vera_smt_over_off"], smt)

    sc = read_csv("npb/nas-scaling.csv")
    if sc is not None:
        # one block per kernel; columns: cores, then one column per series
        series = [("grace", "base"), ("vera", "base"), ("vera", "smt"),
                  ("turin-9r45", "base"), ("gnr", "base")]
        present = {(a, v) for a, v in zip(sc["arch"], sc["variant"])}
        for s in series:
            if s not in present:
                warn(f"nas-scaling.csv has no {s[0]} {s[1]} rows")
        blocks, kernels = [], []
        for k in NAS_KERNELS:
            d = sc[sc["kernel"] == k]
            if d.empty:
                warn(f"nas-scaling.csv has no {k} - its panel stays empty")
            cores = sorted(d["cores"].unique()) or [float("nan")]
            block = []
            for c in cores:
                row = [c]
                for a, v in series:
                    x = d[(d["arch"] == a) & (d["variant"] == v) & (d["cores"] == c)]["mops"]
                    row.append(float(x.iloc[0]) if len(x) else float("nan"))
                block.append(row)
            blocks.append(block)
            kernels.append(k)
        write("nas-scaling", ["cores", "grace", "vera", "vera_smt", "turin", "gnr",
                              "(index i = kernel", *kernels, ")"], [], blocks)


# --- Figs: miniapps whole-chip speedup + scaling vs 1 Grace core -------------

def miniapps() -> None:
    sc = read_csv("miniapps/scaling.csv")
    if sc is None:
        return
    if "variant" not in sc.columns:
        sc["variant"] = "base"          # older CSVs have SMT-off rows only
    mt = read_csv("mt-comparison/mt-comparison.csv")

    def t(a, app, cores=None, variant="base"):
        d = sc[(sc["arch"] == a) & (sc["app"] == app) & (sc["variant"] == variant)]
        if d.empty:
            return float("nan")
        d = d[d["cores"] == (cores or d["cores"].max())]
        return float(d["time_s"].iloc[0]) if len(d) else float("nan")

    def vera_smt_fullchip(app):
        v = t("vera", app, variant="smt")
        if np.isfinite(v):
            return v
        if mt is not None:
            # scale the separate SMT on/off experiment onto the sweep's SMT-off time
            d = mt[(mt["arch"] == "vera") & (mt["app"] == app)].set_index("mt")
            if {"on", "off"} <= set(d.index):
                return t("vera", app) * d.loc["on", "time_avg_s"] / d.loc["off", "time_avg_s"]
        return float("nan")

    if "grace" not in set(sc["arch"]):
        warn("miniapps/scaling.csv has no Grace rows - miniapp figures skipped")
        return

    rows = []
    for app, label, case in MINIAPPS:
        g = t("grace", app)
        # long label (full-width figure): name over test case; short label
        # (one-column figure, tick labels rotated): name only
        rows.append([stack(label, case), g / t("vera", app), g / vera_smt_fullchip(app),
                     g / t("turin-9r45", app), g / t("gnr", app), label])
    rows += summary_rows(rows, {1: 0})
    write("miniapp-speedup", ["app", "vera", "vera_smt", "turin", "gnr", "short_label"], rows)

    blocks = []
    for app, _, _ in MINIAPPS:
        g1 = t("grace", app, cores=1)
        cores = sorted(sc[sc["app"] == app]["cores"].unique())
        block = []
        for c in cores:
            row = [c]
            for a, v in [("grace", "base"), ("vera", "base"), ("vera", "smt"),
                         ("turin-9r45", "base"), ("gnr", "base")]:
                row.append(g1 / t(a, app, cores=c, variant=v)
                           if c <= CORES[a] else float("nan"))
            block.append(row)
        blocks.append(block)
    write("miniapp-scaling", ["cores", "grace", "vera", "vera_smt", "turin", "gnr",
                              "(index i = app", *[m[0] for m in MINIAPPS], ")"], [], blocks)


# --- Fig: scientific applications -------------------------------------------
# Expected input (not in the repo yet): data/applications/apps.csv with columns
#   app,case,metric,arch,variant,value
# metric = "time" (lower is better) or "rate" (higher is better, e.g. ns/day);
# variant = base | smt. One row per (app, arch, variant).

APPS = [("castep", "CASTEP", "al3x3"), ("cp2k", "CP2K", "fayalite"),
        ("gromacs", "GROMACS", "TestCaseB"), ("namd", "NAMD", "stmv"),
        ("openfoam", "OpenFOAM", "hpc_motorbike"), ("wrf", "WRF", "corus12k")]


def applications() -> None:
    df = read_csv("applications/apps.csv")
    if df is None:
        return
    series = [("vera", "base"), ("vera", "smt"), ("turin-9r45", "base"),
              ("gnr", "base"), ("gnr", "smt")]
    rows = []
    for app, label, case in APPS:
        d = df[df["app"].str.lower() == app]
        if d.empty:
            warn(f"apps.csv has no {label}")
            continue

        def val(a, v):
            x = d[(d["arch"] == a) & (d["variant"] == v)]["value"]
            return float(x.iloc[0]) if len(x) else float("nan")

        g = val("grace", "base")
        higher = d["metric"].iloc[0] == "rate"
        # OpenFOAM: asterisk on the name (no SMT-on run: native threading is
        # unsupported; explained in the caption). "(hpc_motorbike)" is the
        # widest label: shift it 4pt left so it does not touch "(corus12k)".
        name = label + (r"$^{*}$" if app == "openfoam" else "")
        rows.append([stack(name, case, 8 if app == "openfoam" else 0)] +
                    [(val(a, v) / g) if higher else (g / val(a, v)) for a, v in series] +
                    [label])
    rows += summary_rows(rows, {1: 0, 4: 3})
    write("apps-speedup", ["app", "vera", "vera_smt", "turin", "gnr", "gnr_smt", "short_label"], rows)


def main() -> int:
    print("[prep] reading", DATA.relative_to(ROOT), "and results/c2c")
    for step in (stream, tlb, c2c, nas, miniapps, applications):
        try:
            step()
        except Exception as e:          # keep going; build.py reports what is missing
            warn(f"{step.__name__} failed: {e!r}")
    (OUT / "written.txt").write_text("\n".join(written) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
