"""Parse NAS Parallel Benchmarks (OpenMP) results into data/npb/.

Two kinds of raw input, both discovered by globbing every arch directory under
results/npb/ for filenames of the form `nas-<CLASS>[-variant]...` — a new
architecture (or a new NAS class) needs no code change, only files on disk.
The class token in the filename becomes the `nas_class` column, so the two
output CSVs are self-describing and can never be silently joined.

*** THE TWO DATASETS ARE DIFFERENT NAS CLASSES. ***
Whole-chip runs are class D; the core-count scaling sweeps are class B. This
was confirmed from the run scripts shipped with the Vera drop —
results/new-results/paper-results-vera/paper-results/scripts/nas/
run_nas_scaling.sh and run_nas_mt_scaling.sh both execute `${kernel}.B.x`
and echo "Running ${KERNEL} (Class B)". It also matches the measurements:
sweep Mop/s at 88 cores differs from the class-D whole-chip figure by
-40%..+210% depending on kernel, and sweep runtimes are 0.03-2.0 s against
5-105 s for class D. Never compare or merge values across the two.

1. Whole-chip runs, class D: concatenated NPB stdout with `-----Running XX-----`
   separators. Figure of merit is `Mop/s total`.  ->  data/npb/nas-D.csv

     <arch>/nas-D.txt          all physical cores, SMT off      variant=base
     <arch>/nas-D-smt.txt      all physical cores, SMT on       variant=smt
     <arch>/nas-D-smt-72c.txt  72 cores, SMT on (144 threads)   variant=smt-72c

   Single-kernel supplements are recognised the same way as the sweeps:
   <arch>/nas-D-<kernel>[-smt].txt holds one kernel run on its own. gnr has the
   pair nas-D-is.txt / nas-D-is-smt.txt, the only class-D SMT measurement on any
   chip but Vera. Supplement rows are KEPT alongside the suite rather than
   deduped, tagged by a `source` column ("suite", or the supplement's stem), so
   a consumer can choose: per-kernel figures want the suite's copy for
   consistency, while an SMT ratio wants a matched same-session pair.

   Present today: grace (72t), vera (88t / 176t / 144t), gnr (96t),
   turin-9r45 (96t).

2. Core-count scaling sweeps, class B, already delivered as CSV (no stdout
   parsing).  ->  data/npb/nas-scaling.csv

     <arch>/nas-B-scaling.csv      kernel,cores,mops,runtime_s          variant=base
     <arch>/nas-B-smt-scaling.csv  kernel,cores,threads,mops,runtime_s  variant=smt

   A future nas-D-scaling.csv would be picked up automatically and tagged
   nas_class=D.

   SINGLE-KERNEL SUPPLEMENTS: <arch>/nas-B-<kernel>-scaling.csv (and the -smt
   form) hold one kernel re-run on its own. Both x86 chips' suite sweeps were
   collected before IS was added to the harness, so IS was re-run separately
   afterwards. A supplement only FILLS GAPS — where the whole-suite sweep
   already has that kernel the supplement is reported and ignored, so every
   kernel on one figure comes from a single session. gnr's IS SMT supplement is
   such a re-run (it agrees with the suite sweep within ~4%); gnr's and
   turin-9r45's IS SMT-off supplements are genuine gap-fills.

Note on verification: some vendors' kernels print extra free-text strings
("Verification Successful", "VERIFICATION SUCCESSFUL", "Result verification
successful") alongside the canonical `Verification    =   SUCCESSFUL` line.
Only the `Verification\\s*=\\s*` form is parsed, so those are ignored; the
parser prints the per-file kernel count so silent drops are visible.

Renames applied to raw files (provenance):
  June 2026:  grace/grace_nas.txt -> grace/nas-D.txt,
              vera/OMP-nas-D.txt -> vera/nas-D.txt,
              vera/OMP-nas-D-MT.txt -> vera/nas-D-smt.txt,
              vera/OMP-nas-D-MT-72.txt -> vera/nas-D-smt-72c.txt
  July 2026 (see scripts/stage_new_results.sh):
              gnr-results/nas/nas_D-gnr.out    -> gnr/nas-D.txt
              turin-results/nas/nas_D-turin.out -> turin-9r45/nas-D.txt
              paper-results/nas/nas.out         -> vera/nas-D.txt (refreshed)
              paper-results/nas/nas_mt.out      -> vera/nas-D-smt.txt (refreshed)
              paper-results/nas/nas_scaling.out    -> vera/nas-B-scaling.csv
              paper-results/nas/nas_mt_scaling.out -> vera/nas-B-smt-scaling.csv
              (first staged as nas-D-*-scaling.csv, renamed to nas-B-* once the
               run scripts confirmed the sweeps are class B, not class D)
"""

import re
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from scripts.common import style

RAW = style.RESULTS_DIR / "npb"
OUT = style.DATA_DIR / "npb"

# Filenames are keyed off a NAS class token so a new class needs no code
# change: nas-<CLASS>[-<variant>].txt for whole-chip stdout, and
# nas-<CLASS>[-smt]-scaling.csv for core-count sweeps.
CHIP_GLOB = ("nas-?.txt", "nas-?-*.txt")
CHIP_RE = re.compile(r"^nas-(?P<cls>[A-F])(?:-(?P<kernel>[a-z]{2}))?"
                     r"(?:-(?P<variant>smt|smt-72c))?\.txt$")

# Some machines report the whole-chip run as a CSV summary rather than NPB
# stdout (Grace's `nas-classD-full-socket.csv`). Same columns as a sweep CSV but
# a single core count. The `-scaling` suffix keeps this from colliding with the
# core-count sweeps below.
CHIP_CSV_GLOB = ("nas-?.csv", "nas-?-*.csv")
CHIP_CSV_RE = re.compile(r"^nas-(?P<cls>[A-F])(?:-(?P<variant>smt|smt-72c))?\.csv$")

# A sweep file may cover the whole suite (nas-B-scaling.csv) or a SINGLE kernel
# (nas-B-is-scaling.csv). Single-kernel files exist because both x86 chips' suite
# sweeps were collected before IS joined the harness, so IS was re-run on its own
# afterwards. The kernel token is two lowercase letters, which cannot collide
# with the three-letter "smt" variant token.
SCALING_GLOB = ("nas-?-scaling.csv", "nas-?-smt-scaling.csv",
                "nas-?-??-scaling.csv", "nas-?-??-smt-scaling.csv")
SCALING_RE = re.compile(r"^nas-(?P<cls>[A-F])(?:-(?P<kernel>[a-z]{2}))?"
                        r"(?:-(?P<variant>smt))?-scaling\.csv$")

# Order variants are emitted in, for stable output.
VARIANT_ORDER = ["base", "smt", "smt-72c"]

# Full NPB OpenMP kernel set. IS was added to the harness partway through, so
# older runs have eight of these; the parser reports which are absent.
KERNELS = {"BT", "CG", "EP", "FT", "IS", "LU", "MG", "SP", "UA"}

# The trailing period is optional: every kernel prints "XX Benchmark Completed."
# except IS, which omits it. Requiring the period silently dropped IS from every
# class-D run once it was added to the suite.
BLOCK_RE = re.compile(
    r"(?P<kernel>[A-Z]{2}) Benchmark Completed\.?(?P<body>.*?)(?=-----Running|\Z)",
    re.S)


def _field(body: str, name: str) -> str | None:
    m = re.search(rf"{name}\s*=\s*(\S+)", body)
    return m.group(1) if m else None


def _arch_dirs():
    """(arch_id, dir) for every registry arch that has a results dir."""
    absent = []
    for arch_id in style.arch_order():
        d = RAW / arch_id
        if d.is_dir():
            yield arch_id, d
        else:
            absent.append(arch_id)
    if absent:
        print(f"warning: no results/npb/ directory for {', '.join(absent)}, "
              f"skipping")


def _matching(d: Path, globs, regex):
    """(path, nas_class, variant, kernel) for every recognised file in an arch dir.

    `kernel` is None for a whole-suite file and the kernel id for a
    single-kernel supplement. Whole-suite files sort FIRST within a
    (class, variant), which is what lets parse_scaling treat a supplement as a
    gap-filler rather than an override.
    """
    found = {}
    for g in globs:
        for p in d.glob(g):
            m = regex.match(p.name)
            if m and p.name not in found:
                kernel = m.groupdict().get("kernel")
                found[p.name] = (p, m.group("cls"), m.group("variant") or "base",
                                 kernel.upper() if kernel else None)
    return sorted(found.values(),
                  key=lambda t: (t[1], VARIANT_ORDER.index(t[2]),
                                 t[3] is not None, t[3] or ""))


def parse_chip_runs() -> pd.DataFrame:
    """Whole-chip NPB stdout -> one row per (arch, nas_class, variant, kernel)."""
    rows = []
    for arch_id, d in _arch_dirs():
        matches = _matching(d, CHIP_GLOB, CHIP_RE)
        csv_matches = _matching(d, CHIP_CSV_GLOB, CHIP_CSV_RE)
        if not matches and not csv_matches:
            print(f"warning: no whole-chip NPB run (stdout or CSV) in "
                  f"{d.relative_to(style.REPO_ROOT)}, skipping")
        for path, nas_class, variant, one_kernel in matches:
            fname = path.name
            # Provenance, so a consumer can tell a whole-suite run from a
            # single-kernel supplement collected in its own session. Both are
            # kept: the suite is what the per-kernel figures use, but an
            # SMT ratio needs a MATCHED pair and must be able to find one.
            source = "suite" if one_kernel is None else path.stem
            text = path.read_text(encoding="utf-8", errors="replace")
            seen = set()
            for m in BLOCK_RE.finditer(text):
                body, kernel = m.group("body"), m.group("kernel")
                verified = _field(body, "Verification")
                threads = _field(body, "Total threads")
                mops = _field(body, r"Mop/s total")
                if threads is None or mops is None:
                    print(f"warning: {arch_id}/{variant} {kernel}: missing "
                          f"Mop/s or thread count, dropping")
                    continue
                if verified != "SUCCESSFUL":
                    print(f"warning: {arch_id}/{variant} {kernel} "
                          f"verification = {verified}, keeping but flagged")
                seen.add(kernel)
                rows.append({
                    "arch": arch_id,
                    "nas_class": nas_class,
                    "variant": variant,
                    "kernel": kernel,
                    "threads": int(threads),
                    "mops": float(mops),
                    "time_s": float(_field(body, "Time in seconds")),
                    "verified": verified == "SUCCESSFUL",
                    "source": source,
                })
            print(f"  {arch_id}/{fname}: {len(seen)} kernels "
                  f"(class {nas_class}, {variant}, {source})")
            if one_kernel is None:
                # The suite is BT CG EP FT IS LU MG SP UA. Runs collected before
                # IS was added to the harness legitimately have eight, so name
                # what is missing rather than warning on a bare count.
                short = KERNELS - seen
                if short:
                    print(f"  note: {arch_id}/{fname} has no "
                          f"{', '.join(sorted(short))} result")
            elif seen != {one_kernel}:
                print(f"warning: {arch_id}/{fname} is named for {one_kernel} "
                      f"but contains {', '.join(sorted(seen))}")

        # whole-chip runs delivered as a CSV summary instead of stdout
        for path, nas_class, variant, _ in csv_matches:
            df = pd.read_csv(path)
            need = {"kernel", "cores", "mops", "runtime_s"}
            if not need <= set(df.columns):
                print(f"warning: {arch_id}/{path.name} lacks {sorted(need - set(df.columns))}, "
                      f"skipping")
                continue
            for r in df.itertuples():
                rows.append({
                    "arch": arch_id,
                    "nas_class": nas_class,
                    "variant": variant,
                    "kernel": str(r.kernel).upper(),
                    # SMT off unless the filename says otherwise, so one thread
                    # per core; the CSV records no separate thread count
                    "threads": int(r.cores) * (2 if variant.startswith("smt") else 1),
                    "mops": float(r.mops),
                    "time_s": float(r.runtime_s),
                    # This format carries no verification field, and the run
                    # logs do not record one either. Treated as verified so the
                    # run is usable, but it has NOT been independently checked.
                    "verified": True,
                    "source": "suite",
                })
            seen = {str(k).upper() for k in df["kernel"]}
            print(f"  {arch_id}/{path.name}: {len(seen)} kernels "
                  f"(class {nas_class}, {variant}, CSV summary — no "
                  f"verification field)")
            short = KERNELS - seen
            if short:
                print(f"  note: {arch_id}/{path.name} has no "
                      f"{', '.join(sorted(short))} result")
    return pd.DataFrame(rows)


def parse_scaling() -> pd.DataFrame:
    """Core-count sweeps -> arch,nas_class,variant,kernel,cores,threads,mops,runtime_s."""
    frames = []
    for arch_id, d in _arch_dirs():
        # (nas_class, variant) -> kernels already taken, so a single-kernel
        # supplement fills gaps instead of overriding the whole-suite sweep.
        # Whole-suite files are visited first (see _matching). Preferring the
        # suite is deliberate: every kernel in one figure then comes from one
        # session, under one set of machine conditions.
        claimed: dict[tuple[str, str], set[str]] = {}
        for path, nas_class, variant, one_kernel in _matching(
                d, SCALING_GLOB, SCALING_RE):
            df = pd.read_csv(path)
            missing = {"kernel", "cores", "mops"} - set(df.columns)
            if missing:
                print(f"warning: {path.relative_to(style.REPO_ROOT)} missing "
                      f"columns {sorted(missing)}, skipping")
                continue
            df["kernel"] = df["kernel"].astype(str).str.upper()
            if one_kernel and set(df["kernel"]) != {one_kernel}:
                print(f"warning: {arch_id}/{path.name} is named for {one_kernel} "
                      f"but contains {sorted(set(df['kernel']))}, skipping")
                continue
            taken = claimed.setdefault((nas_class, variant), set())
            dupes = sorted(set(df["kernel"]) & taken)
            if dupes:
                df = df[~df["kernel"].isin(dupes)].copy()
                print(f"  note: {arch_id}/{path.name} re-runs "
                      f"{', '.join(dupes)}, which the whole-suite class-"
                      f"{nas_class} {variant} sweep already covers — keeping the "
                      f"sweep's copy, ignoring this one")
                if df.empty:
                    continue
            taken |= set(df["kernel"])
            if "threads" not in df.columns:
                df["threads"] = df["cores"]
            if "runtime_s" not in df.columns:
                df["runtime_s"] = pd.NA
            df = df.assign(arch=arch_id, nas_class=nas_class, variant=variant)
            frames.append(df[["arch", "nas_class", "variant", "kernel", "cores",
                              "threads", "mops", "runtime_s"]])
            print(f"  {arch_id}/{path.name}: {len(df)} points, "
                  f"{df['kernel'].nunique()} kernels, "
                  f"{df['cores'].min()}-{df['cores'].max()} cores "
                  f"(class {nas_class}, {variant})")
    if not frames:
        print("warning: no NPB scaling sweeps found, "
              "data/npb/nas-scaling.csv will not be written")
        return pd.DataFrame()
    return pd.concat(frames, ignore_index=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    print("whole-chip runs:")
    chip = parse_chip_runs()
    if chip.empty:
        print("warning: no whole-chip NPB results found at all")
    else:
        chip.to_csv(OUT / "nas-D.csv", index=False)
        print(f"wrote {len(chip)} rows "
              f"({chip.groupby(['arch', 'nas_class', 'variant']).size().to_dict()}) "
              f"to {OUT.relative_to(style.REPO_ROOT)}/nas-D.csv")

    print("scaling sweeps:")
    scal = parse_scaling()
    if not scal.empty:
        scal.to_csv(OUT / "nas-scaling.csv", index=False)
        print(f"wrote {len(scal)} rows "
              f"({scal.groupby(['arch', 'nas_class', 'variant']).size().to_dict()}) "
              f"to {OUT.relative_to(style.REPO_ROOT)}/nas-scaling.csv")


if __name__ == "__main__":
    main()
