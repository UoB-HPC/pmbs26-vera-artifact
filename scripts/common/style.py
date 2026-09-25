"""Shared plot styling for all benchmark plots.

Single source of truth for colours, fonts, figure defaults, the architecture
registry, and output paths. Benchmark plot scripts must take all styling from
here and never restyle locally.

Import pattern (from any script under scripts/):

    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from scripts.common import style

    style.apply()
    fig, ax = plt.subplots()
    g = style.ARCHES["grace"]
    ax.plot(x, y, color=g.color, marker=g.marker, label=g.label)
    style.save_fig(fig, "stream", "triad-scaling")
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

# --- Repo paths -------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]
RESULTS_DIR = REPO_ROOT / "results"   # raw results, never edited
DATA_DIR = REPO_ROOT / "data"         # parsed, plot-ready CSVs

# Output directory for figures. Defaults to new-plots/ (the current figure set,
# covering Grace + Vera + Turin + GNR); override with PLOTS_SUBDIR to write an
# alternative set without touching any plot script.
PLOTS_DIR = REPO_ROOT / os.environ.get("PLOTS_SUBDIR", "figures")

# Figure file formats, written side by side for every figure. PDF is the paper
# deliverable (vector, Type-42 embedded fonts so the text stays real text); SVG
# is kept alongside it for editing and for pasting into slides. Override with a
# comma-separated PLOTS_FORMAT, e.g. PLOTS_FORMAT=pdf or PLOTS_FORMAT=png, to
# emit something else without editing a plot script.
PLOTS_FORMATS = [f.strip().lower()
                 for f in os.environ.get("PLOTS_FORMAT", "pdf,svg").split(",")
                 if f.strip()]

# Figure titles are OFF by default: every figure is captioned in the paper, so a
# title duplicates the caption and wastes vertical space. Plot scripts still set
# titles — save_fig strips the figure-level ones — so a title is one env var
# away (PLOTS_TITLES=1) and nothing has to be re-written to bring them back.
# Only figure-level titles go: a suptitle, or the title of a single-axes figure.
# Per-panel titles in a small-multiple grid name the panel (kernel, chip, app)
# and are content, not decoration, so they always stay.
SHOW_TITLES = os.environ.get("PLOTS_TITLES", "0").strip().lower() \
    not in ("", "0", "false", "no")

# --- Architecture registry ---------------------------------------------------
# Adding a new chip = adding one entry here. Nothing else should hard-code
# architecture names, colours, or core counts.


@dataclass(frozen=True)
class Arch:
    id: str        # directory/file naming id, e.g. results/stream/<id>/
    label: str     # display name used in legends
    color: str
    cores: int     # physical cores
    marker: str
    smt: int = 1   # hardware threads per core (2 = SMT on available)
    short: str = ""  # compact name for bar ticks / annotations
    vendor: str = ""  # NVIDIA / AMD / Intel, for figures that name the maker

    @property
    def threads(self) -> int:
        """Maximum hardware threads on the chip."""
        return self.cores * self.smt

    @property
    def short_label(self) -> str:
        """Compact name, for axis ticks and in-plot annotations."""
        return self.short or self.label.split(" (")[0]

    @property
    def vendor_label(self) -> str:
        """Vendor-prefixed chip name, e.g. "NVIDIA Grace", "AMD EPYC 9R45"."""
        return f"{self.vendor} {self.short_label}".strip()

    @property
    def titled(self) -> str:
        """Vendor, chip and core count on one line — for panel titles."""
        return f"{self.vendor_label} ({self.cores} cores)"


BASELINE = "grace"  # all speedup plots normalise against this arch

# Reference text used on speedup axes. Grace's *single core* is the preferred
# reference; benchmarks with no Grace 1-core datapoint fall back to the
# whole-chip label (see speedup_axis).
SINGLE_CORE_REF = "1 Grace core"
WHOLE_CHIP_REF = "Grace (72c)"

ARCHES: dict[str, Arch] = {
    # id             label                        colour    cores  mk  smt  short
    "grace":      Arch("grace",      "Grace (72c)",              "#4A7FB5", 72,  "o", 1, "Grace", "NVIDIA"),        # steel blue (baseline)
    "vera":     Arch("vera",     "Vera (88c)",               "#5F9E00", 88,  "s", 2, "Vera", "NVIDIA"),         # NVIDIA green (hero)
    "turin-9r45": Arch("turin-9r45", "AMD EPYC 9R45 (96c)",      "#CC0000", 96,  "D", 1, "EPYC 9R45", "AMD"),    # AMD red
    # gnr: Intel blue, deliberately brighter and cyan-shifted so it stays separable
    # from Grace's muted steel blue when both are on one figure (markers differ too).
    # smt=2 confirmed by results/sysinfo/gnr/lscpu.txt ("Thread(s) per core: 2") and
    # by its mt-comparison run using 192 threads. Most gnr runs are still 96-thread,
    # so plots that need the threads a run actually used must read that from the
    # parsed data, not from Arch.threads.
    "gnr":        Arch("gnr",        "Intel Xeon 6975P-C (96c)", "#00A9E0", 96,  "P", 2, "Xeon 6975P-C", "Intel"), # Intel blue
}

# --- Cache hierarchy ---------------------------------------------------------
# Per-arch cache sizes in bytes, for boundary annotations on working-set sweeps
# (test-tlb). Sizes are what a SINGLE thread can occupy, so
# private levels are per-core and shared levels are per sharing domain — which
# for AMD is one CCD, not the socket total.
#
# Sources: results/sysinfo/<arch>/lscpu.txt, except Grace (no lscpu captured;
# published Neoverse V2 / Grace figures).
CACHE_LEVELS: dict[str, dict[str, int]] = {
    # lscpu totals -> per-thread sizes:
    #   grace       64 KiB L1d, 1 MiB L2 per core, 114 MiB shared L3
    #   vera      8.3 MiB/88 L1d, 176 MiB/88 L2, 164 MiB L3 (1 instance)
    #   turin-9r45  9 MiB/192 L1d, 192 MiB/192 L2, 768 MiB/24 instances L3
    #               -> 32 MiB per CCD, which is the limit for one thread
    #   gnr         4.5 MiB/96 L1d, 192 MiB/96 L2, 480 MiB L3 (1 instance)
    "grace":      {"L1d": 64 << 10, "L2": 1 << 20, "L3": 114 << 20},
    "vera":     {"L1d": 96 << 10, "L2": 2 << 20, "L3": 164 << 20},
    "turin-9r45": {"L1d": 48 << 10, "L2": 1 << 20, "L3": 32 << 20},
    "gnr":        {"L1d": 48 << 10, "L2": 2 << 20, "L3": 480 << 20},
}

# Line style per cache level, so a level is recognisable across arch colours.
CACHE_LINESTYLE = {"L1d": ":", "L2": "--", "L3": "-."}

# Non-architecture accent, for reference lines and ideal-scaling guides. Series
# that are not architectures (per-kernel, per-app) take SERIES_COLORS.
REFERENCE_COLOR = "#777777"
SERIES_COLORS = plt.get_cmap("tab10").colors

# Shared sequential colormap for matrix/heatmap figures (c2c): green = low, yellow = middle, red = high.
# For a metric where high is *good* (bandwidth), use HEATMAP_CMAP.reversed().
HEATMAP_CMAP = LinearSegmentedColormap.from_list(
    "green_yellow_red", ["#2f9e44", "#ffe066", "#d90429"]
)


def arch_order(ids=None) -> list[str]:
    """Arch ids in canonical plot order: baseline first, then registry order."""
    ids = list(ARCHES) if ids is None else [i for i in ARCHES if i in set(ids)]
    return sorted(ids, key=lambda i: (i != BASELINE, list(ARCHES).index(i)))

# --- Global matplotlib style -------------------------------------------------


def apply() -> None:
    """Apply the shared rcParams. Call once at the top of every plot script."""
    plt.rcParams.update({
        "figure.figsize": (10.0, 6.0),
        "savefig.bbox": "tight",
        "svg.fonttype": "none",        # keep text editable in the SVG
        "pdf.fonttype": 42,            # embed TrueType, so PDF text stays real text
        "ps.fonttype": 42,
        "font.family": "sans-serif",
        "font.size": 12,
        "axes.labelsize": 13,
        "axes.titlesize": 14,
        "axes.titleweight": "bold",
        "axes.titlepad": 10,
        "xtick.labelsize": 11,
        "ytick.labelsize": 11,
        "legend.fontsize": 11,
        "legend.frameon": False,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "axes.grid": True,
        "axes.axisbelow": True,
        "grid.alpha": 0.3,
        "lines.linewidth": 2.0,
        "lines.markersize": 6,
    })


# --- Helpers -----------------------------------------------------------------


def lighten(color: str, amount: float = 0.45) -> tuple:
    """Blend a colour towards white, for variant series of the same chip."""
    from matplotlib.colors import to_rgb
    r, g, b = to_rgb(color)
    return (r + (1 - r) * amount, g + (1 - g) * amount, b + (1 - b) * amount)


def _strip_titles(fig) -> None:
    """Drop figure-level titles, keeping per-panel ones (see SHOW_TITLES).

    A colourbar is an axes too, so it is excluded before deciding whether a
    figure is a single panel — otherwise a heatmap plus its colourbar would look
    like a small-multiple grid and keep its title.
    """
    if fig._suptitle is not None:
        fig.suptitle("")
    panels = [a for a in fig.axes if a.get_label() != "<colorbar>"]
    if len(panels) == 1:
        panels[0].set_title("")


def save_fig(fig, benchmark: str, name: str) -> Path:
    """Save a figure under <plots dir>/<benchmark>/<name>.<ext>.

    Writes one file per entry in PLOTS_FORMATS (PDF by default — see the
    PLOTS_FORMAT env var) and returns the path of the first one.
    """
    if not SHOW_TITLES:
        _strip_titles(fig)
    written = []
    for fmt in PLOTS_FORMATS:
        out = PLOTS_DIR / benchmark / f"{name}.{fmt}"
        out.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(out, format=fmt)
        written.append(out)
    # PLOTS_SUBDIR may be an absolute path outside the repo, so relative_to is
    # only a nicety for the log line, never a requirement.
    def pretty(p: Path) -> str:
        try:
            return str(p.relative_to(REPO_ROOT))
        except ValueError:
            return str(p)

    print("wrote " + ", ".join(pretty(p) for p in written))
    return written[0]


def baseline_line(ax, y: float = 1.0) -> None:
    """Horizontal reference line for speedup plots (baseline = 1.0)."""
    ax.axhline(y, color=ARCHES[BASELINE].color, linewidth=1, linestyle="--",
               zorder=1)


def speedup_axis(ax, reference: str = SINGLE_CORE_REF, line: bool = True) -> None:
    """Label conventions for speedup-vs-baseline plots.

    `reference` names what 1.0 means. Use style.SINGLE_CORE_REF where a Grace
    single-core datapoint exists (the preferred baseline), WHOLE_CHIP_REF where
    only a full-chip Grace run is available, or a custom string (e.g. "own 1
    core") for self-relative scaling plots.
    """
    ax.set_ylabel(f"Speedup vs {reference} (×)")
    if line:
        baseline_line(ax)


_NOTE_CORNERS = {
    # corner -> (x, y, ha, va); y is nudged in from the edge, more so on Axes.
    "lower right": (0.99, 0.02, "right", "bottom"),
    "lower left":  (0.01, 0.02, "left", "bottom"),
    "upper right": (0.99, 0.98, "right", "top"),
    "upper left":  (0.01, 0.98, "left", "top"),
}


def note(target, text: str, loc: str = "lower right") -> None:
    """Small italic caveat in a corner of an Axes or Figure.

    `target` may be an Axes (annotates that panel) or a Figure (annotates the
    figure corner — use this on small-multiple grids, where an axes-anchored
    note overflows into neighbouring panels). `loc` picks the corner; move the
    note when the default bottom-right corner already holds data or labels.
    """
    if loc not in _NOTE_CORNERS:
        raise ValueError(f"note loc must be one of {sorted(_NOTE_CORNERS)}")
    x, y, ha, va = _NOTE_CORNERS[loc]
    kw = dict(ha=ha, va=va, fontsize=9, style="italic", color="0.35")
    if hasattr(target, "transAxes"):
        target.text(x, y, text, transform=target.transAxes, **kw)
    else:
        target.text(x, min(max(y, 0.01), 0.99), text, **kw)


def missing_baseline_note(target, text: str = "no Grace data yet",
                          loc: str = "lower right") -> None:
    """Corner annotation for plots still waiting on baseline results."""
    note(target, text, loc=loc)


def series_color(i: int) -> tuple:
    """Colour for the i-th non-architecture series (kernels, apps, ...)."""
    return SERIES_COLORS[i % len(SERIES_COLORS)]


def ideal_line(ax, xmax: float, xmin: float = 1.0, label: str = "ideal (linear)") -> None:
    """Dotted y = x guide for speedup-vs-core-count plots."""
    ax.plot([xmin, xmax], [xmin, xmax], linestyle=":", linewidth=1.2,
            color=REFERENCE_COLOR, label=label, zorder=1)


def variant_style(color: str) -> dict:
    """Bar kwargs for a variant series of the same chip (e.g. SMT on).

    Lightened fill + hatch keeps the architecture colour identifiable while
    marking the series as a variant.
    """
    return dict(color=lighten(color), hatch="//", edgecolor=color, linewidth=0.8)


def figure_legend(fig, ax=None, ncols: int | None = None, **kw) -> None:
    """Shared, de-duplicated legend below a small-multiple grid.

    Collects handles from every axes on the figure (or just `ax`), so each
    series appears once regardless of which panels drew it.
    """
    axes = [ax] if ax is not None else fig.axes
    seen, pairs = set(), []
    for a in axes:
        for h, l in zip(*a.get_legend_handles_labels()):
            if l not in seen:
                seen.add(l)
                pairs.append((h, l))
    if not pairs:
        return
    handles, labels = zip(*pairs)
    fig.legend(handles, labels, ncols=ncols or min(len(pairs), 4),
               loc="outside lower center", **kw)


def plain_ticks(axis) -> None:
    """Plain (non-scientific) numeric labels on a log-scaled axis.

    Pass e.g. `ax.yaxis`. Values >= 1 print without decimals, smaller values
    keep enough precision to stay distinguishable.
    """
    from matplotlib.ticker import FuncFormatter, NullFormatter

    def fmt(v, _pos):
        if v <= 0:
            return ""
        if v >= 100:
            return f"{v:,.0f}"
        if v >= 10:
            return f"{v:.0f}"
        if v >= 1:
            return f"{v:g}"
        return f"{v:.2f}".rstrip("0").rstrip(".")

    axis.set_major_formatter(FuncFormatter(fmt))
    axis.set_minor_formatter(NullFormatter())


def bytes_label(nbytes: float) -> str:
    """Human byte-size label, e.g. 4096 -> '4K', 1 << 30 -> '1G'."""
    for suffix, unit in (("G", 1 << 30), ("M", 1 << 20), ("K", 1 << 10)):
        if nbytes >= unit:
            value = nbytes / unit
            return f"{value:g}{suffix}"
    return f"{nbytes:g}"


def size_axis(ax, sizes, labels=None, base: int = 4, axis: str = "x") -> None:
    """Log-scaled working-set-size axis, labelled at powers of `base`.

    `sizes` are byte counts (the full sweep, including off-pattern points such
    as test-tlb's 6M); `labels` are the matching display strings, defaulting to
    bytes_label(). Only sizes that are an exact power of `base` times the
    smallest size get a tick, so a 4k->4G sweep gets 4K/16K/64K/... rather than
    22 crowded labels. Minor ticks are removed.
    """
    from math import isclose, log
    from matplotlib.ticker import FixedLocator, FuncFormatter, NullLocator

    sizes = [float(s) for s in sizes]
    if not sizes:
        return
    text = ({s: str(t) for s, t in zip(sizes, labels)} if labels is not None
            else {s: bytes_label(s) for s in sizes})

    ordered = sorted(set(sizes))
    smallest = ordered[0]
    ticks = [s for s in ordered
             if isclose(log(s / smallest, base), round(log(s / smallest, base)),
                        abs_tol=1e-9)]

    target = ax.xaxis if axis == "x" else ax.yaxis
    (ax.set_xscale if axis == "x" else ax.set_yscale)("log", base=2)
    target.set_major_locator(FixedLocator(ticks))
    target.set_major_formatter(
        FuncFormatter(lambda v, _pos: text.get(v, bytes_label(v))))
    target.set_minor_locator(NullLocator())


def cache_lines(ax, arch_ids, label: bool = True, top: float = 0.985,
                dy: float = 0.075) -> list[str]:
    """Vertical cache-boundary lines for each arch, in that arch's colour.

    Draws L1d / L2 / L3 from CACHE_LEVELS on a working-set-size x axis. Each
    arch's labels sit on their own horizontal band (dropping by `dy` per arch)
    so boundaries that nearly coincide — several chips share a 48 KiB L1d — do
    not print on top of one another. Returns the arch ids actually annotated,
    so the caller can name them in a caption.
    """
    drawn = []
    trans = ax.get_xaxis_transform()  # x in data coords, y in axes fraction
    for arch_id in arch_ids:
        levels = CACHE_LEVELS.get(arch_id)
        if not levels:
            continue
        color = ARCHES[arch_id].color
        label_y = top - dy * len(drawn)
        for level, size in levels.items():
            ax.axvline(size, color=color, linestyle=CACHE_LINESTYLE[level],
                       linewidth=1.1, alpha=0.7, zorder=0)
            if label:
                ax.text(size, label_y, f" {level}", transform=trans,
                        ha="left", va="top", fontsize=8, color=color,
                        fontweight="bold", zorder=5)
        drawn.append(arch_id)
    return drawn


def tick_step(ax, x: float | None = None, y: float | None = None,
              x_minor: float | None = None, y_minor: float | None = None) -> None:
    """Fixed-interval major (and optional minor) ticks on a linear axis.

    Use where a reader has to look values up off the figure — e.g. STREAM's
    core-count sweeps, where ticks every 8 cores make a plateau's position
    readable. Minor ticks get a fainter gridline than the majors.
    """
    from matplotlib.ticker import MultipleLocator

    for axis, major, minor in ((ax.xaxis, x, x_minor), (ax.yaxis, y, y_minor)):
        if major is not None:
            axis.set_major_locator(MultipleLocator(major))
        if minor is not None:
            axis.set_minor_locator(MultipleLocator(minor))
    ax.grid(which="major", alpha=0.3)
    if x_minor is not None or y_minor is not None:
        ax.grid(which="minor", alpha=0.13, linewidth=0.6)


def legend(ax, **kw) -> None:
    """Legend in canonical arch order, de-duplicated."""
    handles, labels = ax.get_legend_handles_labels()
    seen, pairs = set(), []
    for h, l in zip(handles, labels):
        if l not in seen:
            seen.add(l)
            pairs.append((h, l))
    if pairs:
        ax.legend(*zip(*pairs), **kw)
