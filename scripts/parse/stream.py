"""Parse raw STREAM results into data/stream/.

Inputs (results/stream/<platform>/):
  scaling-sequential.csv   cores,copy_mb_s,scale_mb_s,add_mb_s,triad_mb_s
                           cores added in logical-ID order (0,1,2,...)
  scaling-round-robin.csv  same columns; cores added with a stride of 8
                           (0,8,16,...,1,9,17,...) -- the placement in Fig. 2
  full-cores-best.txt      raw STREAM stdout of the whole-chip run

Only the Triad column is used; MB/s is converted to GB/s (10^9 B/s).

Outputs (data/stream/):
  scaling.csv              arch,placement,cores,triad_gbps
  single-core.csv          arch,core_id,triad_gbps
  best-bandwidth.csv       arch,variant,threads,cores,best_triad_gbps,
                           best_cores,gbps_per_core,full_chip_triad_gbps,source
"""

import re
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from scripts.common import style

RAW = style.RESULTS_DIR / "stream"
OUT = style.DATA_DIR / "stream"

PLACEMENTS = ("sequential", "round-robin")
COMPILERS = (("gcc15", "gcc15_gbps"), ("nvc26.3", "nvc_26_3_gbps"))


def read_scaling(path: Path) -> pd.DataFrame:
    """cores/triad_gbps frame from either raw scaling format."""
    df = pd.read_csv(path)
    if "triad_mb_s" in df.columns:                       # per-kernel MB/s
        return pd.DataFrame({"cores": df["cores"].astype(int),
                             "triad_gbps": df["triad_mb_s"] / 1000.0})
    return pd.DataFrame({"cores": df["Core Count"].astype(int),  # per-compiler
                         "triad_gbps": df["gcc15_gbps"]})


def read_compiler_scaling(path: Path) -> pd.DataFrame | None:
    """cores/gcc15/nvc frame, or None if the file has no nvc column."""
    df = pd.read_csv(path)
    if "nvc_26_3_gbps" not in df.columns:
        return None
    return pd.DataFrame({"cores": df["Core Count"].astype(int),
                         "gcc15_gbps": df["gcc15_gbps"],
                         "nvc_gbps": df["nvc_26_3_gbps"]})


def parse_stream_stdout(path: Path) -> tuple[float, int] | None:
    """(triad GB/s, thread count) from raw STREAM stdout."""
    text = path.read_text()
    triad = re.search(r"^Triad:\s+([\d.]+)", text, re.M)
    if not triad:
        print(f"warning: no Triad line in {path.relative_to(style.REPO_ROOT)}")
        return None
    threads = re.search(r"Number of Threads counted\s*=\s*(\d+)", text)
    return float(triad.group(1)) / 1000.0, int(threads.group(1)) if threads else 0


def compiler_scaling_file(arch_dir: Path, placement: str) -> Path | None:
    """Preferred source of gcc-vs-nvc scaling data for one placement."""
    preserved = arch_dir / f"scaling-{placement}-compilers.csv"
    if preserved.exists():
        return preserved
    plain = arch_dir / f"scaling-{placement}.csv"
    return plain if plain.exists() else None


def main() -> None:
    scaling, single, best, comp_scaling, comp_single = [], [], [], [], []

    for arch_id, arch in style.ARCHES.items():
        arch_dir = RAW / arch_id
        if not arch_dir.is_dir():
            print(f"warning: no stream results for {arch_id}, skipping")
            continue

        # --- scaling sweeps -------------------------------------------------
        seq = None
        candidates = []          # (triad GB/s, cores, source) for best achieved
        for placement in PLACEMENTS:
            f = arch_dir / f"scaling-{placement}.csv"
            if not f.exists():
                print(f"warning: missing {f.relative_to(style.REPO_ROOT)}")
                continue
            df = read_scaling(f)
            if placement == "sequential":
                seq = df
            df.insert(0, "arch", arch_id)
            df.insert(1, "placement", placement)
            scaling.append(df)
            top = df.loc[df["triad_gbps"].idxmax()]
            candidates.append((top["triad_gbps"], int(top["cores"]),
                               f"scaling-{placement} @ {int(top['cores'])} cores"))

            cf = compiler_scaling_file(arch_dir, placement)
            cdf = read_compiler_scaling(cf) if cf else None
            if cdf is not None:
                cdf.insert(0, "arch", arch_id)
                cdf.insert(1, "placement", placement)
                comp_scaling.append(cdf)

        # --- per-core-ID single-core sweep ----------------------------------
        f = arch_dir / "single-core.csv"
        if f.exists():
            df = pd.read_csv(f)
            single.append(pd.DataFrame({"arch": arch_id,
                                        "core_id": df["Core ID"].astype(int),
                                        "triad_gbps": df["gcc15_gbps"]}))
            if "nvc_26_3_gbps" in df.columns:
                for compiler, col in COMPILERS:
                    comp_single.append(pd.DataFrame({
                        "arch": arch_id,
                        "core_id": df["Core ID"].astype(int),
                        "compiler": compiler,
                        "triad_gbps": df[col],
                    }))
        elif seq is not None and (seq["cores"] == 1).any():
            # no per-core sweep: stand in the 1-core sequential-scaling point
            one = seq.loc[seq["cores"] == 1, "triad_gbps"].iloc[0]
            single.append(pd.DataFrame({"arch": [arch_id], "core_id": [0],
                                        "triad_gbps": [one]}))
        else:
            print(f"warning: no single-core bandwidth for {arch_id}")

        # --- whole-chip runs -------------------------------------------------
        full_chip = None
        f = arch_dir / "full-cores-best.txt"
        if f.exists():
            parsed = parse_stream_stdout(f)
            if parsed:
                full_chip, threads = parsed
                candidates.append((full_chip, arch.cores,
                                   f"full-cores-best ({threads}t)"))
        elif seq is not None and (seq["cores"] == arch.cores).any():
            full_chip = seq.loc[seq["cores"] == arch.cores, "triad_gbps"].iloc[0]

        if candidates:
            peak, peak_cores, source = max(candidates)
            best.append({"arch": arch_id, "variant": "smt-off",
                         "threads": arch.cores, "cores": arch.cores,
                         "best_triad_gbps": round(peak, 2),
                         "best_cores": peak_cores,
                         "gbps_per_core": round(peak / arch.cores, 3),
                         "full_chip_triad_gbps": (round(full_chip, 2)
                                                  if full_chip else ""),
                         "source": source})
        else:
            print(f"warning: no bandwidth measurements for {arch_id}")

        f = arch_dir / "full-cores-best-smt.txt"
        if f.exists():
            parsed = parse_stream_stdout(f)
            if parsed:
                gbps, threads = parsed
                best.append({"arch": arch_id, "variant": "smt-on",
                             "threads": threads or arch.threads,
                             "cores": arch.cores,
                             "best_triad_gbps": round(gbps, 2),
                             "best_cores": arch.cores,
                             "gbps_per_core": round(gbps / arch.cores, 3),
                             "full_chip_triad_gbps": round(gbps, 2),
                             "source": f"full-cores-best-smt ({threads}t)"})

    if not scaling:
        print("error: no stream results found at all — nothing written")
        return

    OUT.mkdir(parents=True, exist_ok=True)
    pd.concat(scaling).to_csv(OUT / "scaling.csv", index=False)
    pd.concat(single).to_csv(OUT / "single-core.csv", index=False)
    pd.DataFrame(best).to_csv(OUT / "best-bandwidth.csv", index=False)
    if comp_scaling:
        pd.concat(comp_scaling).to_csv(OUT / "compiler-scaling.csv", index=False)
    if comp_single:
        pd.concat(comp_single).to_csv(OUT / "compiler-single-core.csv", index=False)

    archs = sorted({d["arch"].iloc[0] for d in scaling})
    print(f"wrote {len(scaling)} scaling series for {len(archs)} arches "
          f"({', '.join(archs)}), {len(single)} single-core series, "
          f"{len(best)} best-bandwidth rows to "
          f"{OUT.relative_to(style.REPO_ROOT)}")


if __name__ == "__main__":
    main()
