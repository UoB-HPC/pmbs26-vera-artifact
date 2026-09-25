"""Parse test-tlb latency sweeps into data/test-tlb/latencies.csv.

Input (results/test-tlb/<platform>/latencies-rand-huge-avg.csv), written by
benchmarks/test-tlb/run-avg.sh:
  size,trials,mean_ns
one row per region size from 4k to 4G. Each trial is
  numactl --cpunodebind=0 --membind=0 ./test-tlb -Hr <size> 64
(-H = 2 MiB transparent huge pages, -r = random pointer-chase order,
64 = byte spacing between chain entries). The per-trial output is kept next
to it as latencies-rand-huge-raw.log.

The parser also understands the plain test-tlb stdout format
(`<size>:` headers followed by `X.XXns (~Y.Y cycles)` lines), used by
latencies.txt / latencies-rand-huge.txt files if present.
"""

import re
import sys
from collections import Counter
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from scripts.common import style

RAW = style.RESULTS_DIR / "test-tlb"
OUT = style.DATA_DIR / "test-tlb"

# test-tlb flags -> pattern name used throughout data/ and the plots
FLAGS_TO_PATTERN = {"-H": "seq-huge", "": "seq", "-Hr": "rand-huge", "-r": "rand"}
FULL_PATTERNS = ("seq-huge", "seq", "rand-huge", "rand")
RAND_HUGE = "rand-huge"

# <file name> -> pattern order to assume when the file has no command header
FILE_PATTERNS = {
    "latencies.txt": FULL_PATTERNS,
    "latencies-rand-huge.txt": (RAND_HUGE,),
}

SIZE_RE = re.compile(r"^(\d+)([kMG]):\s*$")
LAT_RE = re.compile(r"^\s*([\d.]+)ns \(~([\d.]+) cycles\)")
CMD_RE = re.compile(r"\./test-tlb\s+(-\S+)?\s*\$i")
SUFFIX = {"k": 1 << 10, "M": 1 << 20, "G": 1 << 30}

# relative difference above which two measurements of the same point are
# reported as disagreeing
DISAGREE_FRAC = 0.15


def _blocks(path: Path) -> tuple[list[tuple[str, int, list[tuple[float, float]]]], str]:
    """Split a raw file into (size_label, size_bytes, [(ns, cycles), ...]) blocks."""
    blocks: list[tuple[str, int, list[tuple[float, float]]]] = []
    header = ""
    for line in path.read_text().splitlines():
        m = SIZE_RE.match(line)
        if m:
            blocks.append((m.group(1) + m.group(2).upper(),
                           int(m.group(1)) * SUFFIX[m.group(2)], []))
            continue
        m = LAT_RE.match(line)
        if m and blocks:
            blocks[-1][2].append((float(m.group(1)), float(m.group(2))))
            continue
        if "./test-tlb" in line and not blocks:
            header = line
    return blocks, header


def _pattern_order(path: Path, header: str, blocks) -> tuple[str, ...] | None:
    """Pattern order for a file: from its command header, else from its shape."""
    flags = CMD_RE.findall(header)
    if flags:
        order = tuple(FLAGS_TO_PATTERN.get((f or "").strip(), "") for f in flags)
        if all(order):
            return order
        print(f"warning: {path.name}: unrecognised test-tlb flags in header, "
              f"falling back to file-name convention")
    if path.name in FILE_PATTERNS:
        expected = FILE_PATTERNS[path.name]
        widths = Counter(len(b[2]) for b in blocks)
        if widths and widths.most_common(1)[0][0] != len(expected):
            print(f"warning: {path.name}: {widths.most_common(1)[0][0]} latency "
                  f"lines per size but name implies {len(expected)}")
        return expected
    print(f"warning: {path.name}: cannot determine access-pattern order, skipping")
    return None


def parse_file(path: Path, arch_id: str) -> list[dict]:
    blocks, header = _blocks(path)
    if not blocks:
        print(f"warning: {path.name}: no size blocks found, skipping")
        return []
    patterns = _pattern_order(path, header, blocks)
    if patterns is None:
        return []
    rows = []
    for label, nbytes, lats in blocks:
        if len(lats) != len(patterns):
            print(f"warning: {arch_id}/{path.name}: {len(lats)} latency lines "
                  f"under {label} (expected {len(patterns)}), truncating")
        for pattern, (ns, cycles) in zip(patterns, lats):
            rows.append({"arch": arch_id, "size_label": label,
                         "size_bytes": nbytes, "pattern": pattern,
                         "latency_ns": ns, "cycles": cycles,
                         "source": path.name})
    return rows


def _check_agreement(arch_id: str, full: list[dict], dedicated: list[dict],
                     old_name: str = "latencies.txt",
                     new_name: str = "latencies-rand-huge.txt") -> None:
    """Warn where two measurements of the same rand-huge point disagree.

    Used both for full-sweep vs dedicated file and for dedicated file vs the
    newer averaged CSV, so the two sources are named by the caller.
    """
    old = {r["size_bytes"]: r["latency_ns"] for r in full if r["pattern"] == RAND_HUGE}
    new = {r["size_bytes"]: r["latency_ns"] for r in dedicated}
    shared = sorted(set(old) & set(new))
    if not shared:
        return
    bad = [(s, old[s], new[s]) for s in shared
           if abs(new[s] - old[s]) / max(old[s], 1e-9) > DISAGREE_FRAC]
    if not bad:
        print(f"  {arch_id}: rand-huge sources agree within "
              f"{DISAGREE_FRAC:.0%} at all {len(shared)} sizes")
        return
    print(f"warning: {arch_id}: {old_name} and {new_name} "
          f"disagree by >{DISAGREE_FRAC:.0%} at {len(bad)}/{len(shared)} sizes "
          f"({new_name} wins):")
    for nbytes, o, n in bad:
        label = next(r["size_label"] for r in dedicated if r["size_bytes"] == nbytes)
        print(f"    {label:>5}: {o:7.2f} ns -> {n:7.2f} ns "
              f"({(n - o) / o:+.0%})")


def parse_avg_csv(path: Path, arch_id: str) -> list[dict]:
    """Averaged rand-hugepages sweep: `size,trials,mean_ns`.

    Written by the drops' scripts/test-tlb/run-avg.sh, which runs
    `numactl --cpunodebind=N --membind=N ./test-tlb -Hr <size> 64` and averages
    10/5/3/1 trials depending on size. Same -Hr pattern as the older one-shot
    files, but pinned and repeated, so it is the better measurement.
    """
    import csv as _csv
    rows = []
    with path.open(newline="") as fh:
        for r in _csv.DictReader(fh):
            label = (r.get("size") or "").strip()
            m = SIZE_RE.match(f"{label}:")
            if not m or not (r.get("mean_ns") or "").strip():
                continue
            rows.append({
                "arch": arch_id,
                "pattern": RAND_HUGE,
                # uppercase the suffix to match parse_file: this file writes
                # "4k" where the text sweeps write "4K", and two spellings of
                # one size would otherwise plot as two separate points
                "size_label": m.group(1) + m.group(2).upper(),
                "size_bytes": int(m.group(1)) * SUFFIX[m.group(2)],
                "latency_ns": float(r["mean_ns"]),
                "cycles": float("nan"),
                "trials": int(r.get("trials") or 1),
                "source": path.name,
            })
    return rows


def parse_arch(arch_id: str) -> list[dict]:
    full_path = RAW / arch_id / "latencies.txt"
    rh_path = RAW / arch_id / "latencies-rand-huge.txt"
    avg_path = RAW / arch_id / "latencies-rand-huge-avg.csv"
    full = parse_file(full_path, arch_id) if full_path.exists() else []
    dedicated = parse_file(rh_path, arch_id) if rh_path.exists() else []
    if avg_path.exists():
        avg = parse_avg_csv(avg_path, arch_id)
        if avg:
            # The averaged, NUMA-pinned sweep supersedes the single-shot -Hr file
            if dedicated:
                _check_agreement(arch_id, dedicated, avg,
                                 "latencies-rand-huge.txt",
                                 "latencies-rand-huge-avg.csv")
            dedicated = avg

    if not full and not dedicated:
        print(f"warning: no test-tlb results for {arch_id}, skipping")
        return []

    if full and dedicated:
        _check_agreement(arch_id, full, dedicated)
        # the dedicated (newer) rand-huge measurement replaces the old one
        full = [r for r in full if r["pattern"] != RAND_HUGE]

    rows = full + dedicated
    patterns = sorted({r["pattern"] for r in rows})
    sizes = len({r["size_label"] for r in rows})
    print(f"  {arch_id}: {len(rows)} rows, {sizes} sizes, patterns {patterns}")
    return rows


def main() -> None:
    rows = []
    for arch_id in style.arch_order():
        rows.extend(parse_arch(arch_id))

    if not rows:
        print("no test-tlb results found — nothing written")
        return

    df = pd.DataFrame(rows).sort_values(["arch", "pattern", "size_bytes"])
    OUT.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT / "latencies.csv", index=False)
    print(f"wrote {len(df)} rows to "
          f"{(OUT / 'latencies.csv').relative_to(style.REPO_ROOT)}")


if __name__ == "__main__":
    main()
