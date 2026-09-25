"""Canonical mini-application registry.

Shared by every benchmark that reports per-application results — currently the
`miniapps` core-count sweeps and the `mt-comparison` SMT on/off runs, which
cover the same four apps and must agree on ids, display labels and units.

Adding an app = adding one entry here.

**Every figure of merit in this family is a TIME, so lower is better.** Raw
files disagree on units (miniBUDE reports milliseconds, the rest seconds);
`SECONDS_PER_UNIT` converts each raw metric column to seconds so downstream
code only ever handles `time_s`.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class App:
    id: str      # directory/file naming id, e.g. results/miniapps/<arch>/<id>-scaling.csv
    label: str   # display name used in titles and legends
    case: str    # benchmark test case the results were collected with


# Order here is the canonical plot order.
APPS: dict[str, App] = {
    "cloverleaf": App("cloverleaf", "CloverLeaf", "bm32_short"),
    "minibude":   App("minibude",   "miniBUDE",   "bm1"),
    "tealeaf":    App("tealeaf",    "TeaLeaf",    "bm_5e_2"),
    "neutral":    App("neutral",    "Neutral",    "stream"),
}

APP_IDS = list(APPS)
APP_LABELS = {a.id: a.label for a in APPS.values()}
APP_CASES = {a.id: a.case for a in APPS.values()}

# Raw metric column name -> (unit as written in the raw file, seconds per unit).
SECONDS_PER_UNIT = {
    "sum_ms": ("ms", 1e-3),
    "wallclock_s": ("s", 1.0),
    "wall_clock_s": ("s", 1.0),
}


def label(app_id: str) -> str:
    """Display label for an app id, falling back to the id itself."""
    a = APPS.get(app_id)
    return a.label if a else app_id


def to_seconds(metric: str) -> float:
    """Multiplier converting a raw metric column to seconds (1.0 if unknown)."""
    return SECONDS_PER_UNIT.get(metric, ("s", 1.0))[1]
