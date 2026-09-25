"""Write data/applications/apps.csv (input of Fig. 11) from
results/applications/app-comparison.csv.

    python gnuplot/make_apps_csv.py

Mapping: unit "s" or "avg_ts" -> metric time (lower is better);
"ns/day" -> metric rate (higher is better). threads_per_core 1 -> base, 2 -> smt.
"""

from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "results" / "applications" / "app-comparison.csv"
DST = ROOT / "data" / "applications" / "apps.csv"

METRIC = {"s": "time", "avg_ts": "time", "ns/day": "rate"}

df = pd.read_csv(SRC, comment="#")
unknown = set(df["unit"]) - set(METRIC)
if unknown:
    raise SystemExit(f"unknown unit(s) {unknown}: add them to METRIC")
out = pd.DataFrame({
    "app": df["app"].str.lower(),
    "case": df["case"],
    "metric": df["unit"].map(METRIC),
    "arch": df["arch"],
    "variant": df["threads_per_core"].map({1: "base", 2: "smt"}),
    "value": df["value"],
})
DST.parent.mkdir(parents=True, exist_ok=True)
# no comment line: prep_data.py reads this file with a plain pd.read_csv
out.to_csv(DST, index=False)
print(f"wrote {DST.relative_to(ROOT)} ({len(out)} rows)")
