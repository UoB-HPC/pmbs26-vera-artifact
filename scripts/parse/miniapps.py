"""Parse raw miniapp core-scaling sweeps into data/miniapps/.

Four HPC miniapps, each run as a 1-core -> full-chip sweep on every machine.
**For every app the figure of merit is TIME, so lower is better.**

Raw files (one directory per arch, `results/miniapps/<arch>/`):

  file                      app         test case    header             unit
  cloverleaf-scaling.csv    CloverLeaf  bm32_short   cores,<machine>    seconds
  minibude-scaling.csv      miniBUDE    bm1          cores,sum_ms       milliseconds
  tealeaf-scaling.csv       TeaLeaf     bm_5e_2      cores,wallclock_s  seconds
  neutral-scaling.csv       Neutral     stream       cores,wallclock_s  seconds

CloverLeaf's second column is named after the *machine* (`gnr`, `turin`,
`vera`), not the metric, so the value column is always taken positionally
(column 1) rather than by name. miniBUDE milliseconds are converted to
seconds so every row shares a single `time_s` column.

Staged from the delivered result drops by scripts/stage_new_results.sh:
  <drop>/cloverleaf/cloverleaf-bm32-short-n-core.csv -> <arch>/cloverleaf-scaling.csv
  <drop>/minibude/minibude-bm1-n-core.csv            -> <arch>/minibude-scaling.csv
  <drop>/tealeaf/tealeaf-bm_5e_2-n-core.csv          -> <arch>/tealeaf-scaling.csv
  <drop>/neutral/neutral-stream-n-core.csv           -> <arch>/neutral-scaling.csv

Outputs:
  data/miniapps/scaling.csv  arch,app,cores,time_s   (the full sweeps)
  data/miniapps/summary.csv  per arch+app: 1-core / best / full-chip times,
                             cores at best, and self-relative speedup at best.

No Grace miniapp results exist yet; the plot script switches to the preferred
Grace-1-core baseline automatically as soon as results/miniapps/grace/ appears.
"""

import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from scripts.common import apps, style

RAW = style.RESULTS_DIR / "miniapps"
OUT = style.DATA_DIR / "miniapps"

# App ids, labels, test cases and unit conversion come from the shared registry
# in scripts/common/apps.py, so miniapps and mt-comparison cannot drift apart.
# Adding a fifth app = adding one entry there.
APP_IDS = apps.APP_IDS
APP_LABELS = apps.APP_LABELS
APP_CASES = apps.APP_CASES


# Run variants: SMT off (one thread per core) and SMT on (two). The SMT sweeps
# are `<app>-scaling-smt.csv` and carry an extra `threads` column.
VARIANTS = {"base": "{app}-scaling.csv", "smt": "{app}-scaling-smt.csv"}

# Runs present on disk that must not be published, as {(arch, app, variant)}.
#
# Empty. Two situations have needed it, both now resolved, and both are worth
# remembering as the shape of problem this guards against:
#  * every miniBUDE run before the "extra" drops settled on ppwi=1 because the
#    work-group size was never set, making them 3-15x slower by very different
#    per-machine factors and mutually incomparable;
#  * vera's miniBUDE SMT sweep briefly lagged the SMT-off one at ppwi=256 /
#    -i 10 while the rest moved to ppwi=32 / -i 100, so the pair would have
#    shown a ppwi change labelled as an SMT effect.
# Both sides of an SMT comparison must share a configuration; check that before
# adding a variant rather than after.
INVALID_RUNS: set[tuple[str, str, str]] = set()


def read_sweep(path: Path) -> pd.DataFrame:
    """cores/time_s frame from a sweep CSV, with an optional threads column.

    The value column is taken as the LAST one, because CloverLeaf names it after
    the machine rather than the metric and the SMT files insert a `threads`
    column before it. Its *name* still drives the unit conversion (`sum_ms` ->
    seconds); an unrecognised name is assumed to be seconds already.
    """
    df = pd.read_csv(path)
    if df.shape[1] < 2:
        raise ValueError(f"{path.name}: expected >=2 columns, got {list(df.columns)}")
    out = pd.DataFrame({
        "cores": pd.to_numeric(df.iloc[:, 0], errors="coerce").astype("Int64"),
        "time_s": pd.to_numeric(df.iloc[:, -1], errors="coerce")
                  * apps.to_seconds(str(df.columns[-1])),
    })
    # threads: present in the SMT files, derived as one per core otherwise
    out["threads"] = (pd.to_numeric(df["threads"], errors="coerce").astype("Int64")
                      if "threads" in df.columns else out["cores"])
    out = out.dropna()
    return (out.astype({"cores": int, "threads": int})
            .sort_values("cores").reset_index(drop=True))


def main() -> None:
    sweeps, summary, anomalies = [], [], []

    for arch_id, arch in style.ARCHES.items():
        arch_dir = RAW / arch_id
        if not arch_dir.is_dir():
            print(f"warning: no miniapp results for {arch_id}, skipping")
            continue

        for app_id in APP_IDS:
          app_label, case = APP_LABELS[app_id], APP_CASES[app_id]
          for variant, pattern in VARIANTS.items():
            if (arch_id, app_id, variant) in INVALID_RUNS:
                print(f"note: skipping {arch_id}/{app_id} ({variant}) — listed "
                      f"in INVALID_RUNS as not comparable (see the comment "
                      f"there); it returns automatically once re-run")
                continue
            f = arch_dir / pattern.format(app=app_id)
            if not f.exists():
                # only the SMT-off sweep is expected everywhere; an absent SMT
                # sweep is normal, not a problem worth warning about
                if variant == "base":
                    print(f"warning: missing {f.relative_to(style.REPO_ROOT)}")
                continue
            try:
                df = read_sweep(f)
            except Exception as exc:                      # never crash the run
                print(f"warning: could not parse {f.relative_to(style.REPO_ROOT)}: {exc}")
                continue
            if df.empty:
                print(f"warning: no usable rows in {f.relative_to(style.REPO_ROOT)}")
                continue

            df.insert(0, "arch", arch_id)
            df.insert(1, "app", app_id)
            df.insert(2, "variant", variant)
            sweeps.append(df)

            one = df[df["cores"] == 1]["time_s"]
            t1 = float(one.iloc[0]) if not one.empty else float("nan")
            best_row = df.loc[df["time_s"].idxmin()]
            max_cores = int(df["cores"].max())
            full = df[df["cores"] == max_cores]["time_s"].iloc[0]
            tag = f"{arch_id}/{app_id}" + ("" if variant == "base" else f" (SMT)")

            if max_cores != arch.cores:
                print(f"note: {tag} sweep tops out at {max_cores} "
                      f"cores (chip has {arch.cores})")
            if int(best_row["cores"]) != max_cores:
                anomalies.append(f"{tag}: best {best_row['time_s']:.3f}s "
                                 f"at {int(best_row['cores'])} cores, "
                                 f"{full:.3f}s at {max_cores} cores")

            summary.append({
                "arch": arch_id,
                "app": app_id,
                "variant": variant,
                "app_label": app_label,
                "case": case,
                "cores_max": max_cores,
                "threads_max": int(df["threads"].max()),
                "time_1core_s": round(t1, 4),
                "time_best_s": round(float(best_row["time_s"]), 4),
                "cores_at_best": int(best_row["cores"]),
                "time_fullchip_s": round(float(full), 4),
                "speedup_best_self": round(t1 / float(best_row["time_s"]), 2),
                "speedup_fullchip_self": round(t1 / float(full), 2),
                "efficiency_best_self": round(t1 / float(best_row["time_s"])
                                              / int(best_row["cores"]), 3),
                "best_at_max_cores": int(best_row["cores"]) == max_cores,
            })

    if not sweeps:
        print("error: no miniapp results found at all — nothing written")
        return

    OUT.mkdir(parents=True, exist_ok=True)
    scaling = pd.concat(sweeps, ignore_index=True)
    scaling.to_csv(OUT / "scaling.csv", index=False)
    summary_df = pd.DataFrame(summary)
    summary_df.to_csv(OUT / "summary.csv", index=False)

    if anomalies:
        print("\nbest time NOT at maximum core count:")
        for a in anomalies:
            print(f"  {a}")

    print(f"\nwrote {len(scaling)} rows over {summary_df['arch'].nunique()} arches "
          f"x {summary_df['app'].nunique()} apps to "
          f"{OUT.relative_to(style.REPO_ROOT)}")
    if style.BASELINE not in set(summary_df["arch"]):
        print(f"note: no {style.BASELINE} miniapp data — plots fall back to "
              "self-relative scaling until results/miniapps/"
              f"{style.BASELINE}/ appears")


if __name__ == "__main__":
    main()
