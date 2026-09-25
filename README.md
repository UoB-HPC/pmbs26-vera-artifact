# Artifact: microarchitectural characterization of NVIDIA Vera for HPC

This archive holds the benchmark scripts, raw results, parsers and figure
scripts behind the paper's Table I and Figures 2-11. Every figure can be
rebuilt from the raw results without access to the hardware.

## Platforms

One socket of each CPU was used. All runs are bound to socket 0 / NUMA node 0.

| id | CPU | cores (SMT) | system |
|---|---|---|---|
| `grace` | NVIDIA Grace | 72 (1) | one socket of a Grace-Grace Superchip node, Isambard 3 |
| `vera` | NVIDIA Vera | 88 (2) | pre-release engineering sample, air-cooled, power-capped to a 450 W TDP equivalent |
| `turin-9r45` | AMD EPYC 9R45 (Zen 5) | 96 (SMT off) | AWS c8a.metal-24xl; `lscpu` shows 2 sockets, socket 0 used |
| `gnr` | Intel Xeon 6975P-C (Granite Rapids) | 96 (2) | AWS c8i.metal-48xl |

`platforms/<id>/` holds `lscpu`, `numactl -H`, `gcc -v` and (where captured)
`lstopo` output. The Vera system is not publicly available. Results on
production Vera systems may differ.

## Layout

```
platforms/<id>/                  system information (Table I)
benchmarks/stream/<id>/          STREAM Makefile, build and run scripts (Fig. 2)
benchmarks/test-tlb/             test-tlb source, Makefile, run-avg.sh (Fig. 3)
benchmarks/c2c/                  core-to-core latency: method (Figs. 4-5)
benchmarks/npb/<id>/             NAS Parallel Benchmarks run scripts (Figs. 6-8)
benchmarks/miniapps/<app>/<id>/  CloverLeaf, TeaLeaf, Neutral, miniBUDE run scripts (Figs. 9-10)
benchmarks/perf/<id>/            perf stat scripts (counter ratios quoted in Sec. V)
applications/                    full applications: Spack environments and run scripts (Fig. 11)
results/<bench>/<id>/            raw results as written by the run scripts
scripts/parse/                   parsers: results/ -> data/
scripts/run_parsers.py           runs all parsers and the applications converter
data/                            parsed CSVs (generated; included for convenience)
gnuplot/                         the figure scripts used for the paper
```

## Rebuild the data and the figures

```bash
pip install -r requirements.txt        # pandas, numpy, matplotlib
python3 scripts/run_parsers.py         # results/ -> data/
python3 gnuplot/build.py               # data/ -> gnuplot/out/<figure>.tex + .pdf
```

`gnuplot/build.py` needs gnuplot >= 5.4 with the `cairolatex` terminal.
`python3 gnuplot/build.py --preview` also builds `gnuplot/preview/preview.pdf`
(needs pdflatex and IEEEtran).

## Paper element -> artifact

| paper | benchmark | raw results | parsed data | figure script |
|---|---|---|---|---|
| Table I | system info | `platforms/` | - | - |
| Fig. 2 | STREAM Triad, round-robin core placement | `results/stream/` | `data/stream/scaling.csv` | `stream-scaling.gp` |
| Fig. 3 | test-tlb random pointer chase | `results/test-tlb/` | `data/test-tlb/latencies.csv` | `tlb-latency.gp` |
| Fig. 4 | core-to-core latency matrices | `results/c2c/` | (read directly) | `c2c-heatmaps.gp` |
| Fig. 5 | core-to-core latency distribution | `results/c2c/` | (read directly) | `c2c-stats.gp` |
| Fig. 6 | NAS class D, whole chip | `results/npb/` | `data/npb/nas-D.csv` | `nas-speedup.gp` (`WIDE=1`) |
| Fig. 7 | NAS class B core sweeps | `results/npb/` | `data/npb/nas-scaling.csv` | `nas-scaling.gp` |
| Fig. 8 | NAS class D, SMT on vs off | `results/npb/` | `data/npb/nas-D.csv` | `nas-smt.gp` |
| Fig. 9 | miniapps, whole chip | `results/miniapps/` | `data/miniapps/scaling.csv` | `miniapp-speedup.gp` |
| Fig. 10 | miniapp core sweeps | `results/miniapps/` | `data/miniapps/scaling.csv` | `miniapp-scaling.gp` |
| Fig. 11 | applications | `results/applications/` | `data/applications/apps.csv` | `apps-speedup.gp` |
| Sec. V | perf stat counters | `results/perf/` | - | - |

## Method in brief

- Compiler: GCC 15.3.0 on all platforms. Arch flags: `-mcpu=olympus` (Vera),
  `-mcpu=neoverse-v2` (Grace), `-march=native` (x86). Exact flags per code
  are in each `benchmarks/*/README.md`.
- Threads: one OpenMP thread per core, pinned with `taskset` and
  `OMP_PROC_BIND`/`OMP_PLACES`. Core sweeps add cores 0..N-1 in order
  (STREAM: also round-robin with stride 8). SMT runs place a second thread on
  each core's sibling hardware thread.
- Repetitions: STREAM reports the best of 100 iterations; test-tlb reports
  the mean of 10/5/3/1 trials depending on region size; miniBUDE reports 100
  iterations; NAS, CloverLeaf, TeaLeaf and Neutral were run once per
  configuration (one pass of each sweep script).
- Figures of merit: STREAM Triad GB/s (10^9 B/s); test-tlb ns per access;
  core-to-core latency in ns as reported by the tool; NAS Mop/s; miniapps wall time.
  Speedups are ratios to Grace.

## What is not included

- Per-core-count raw stdout of the sweeps (several thousand files). The
  CSV files the run scripts wrote from them are included.
- Application binaries and CASTEP source (licensed; see `applications/`).

## Licence

TODO(licence): scripts and code under BSD-3-Clause; results and figures
under CC-BY-4.0 (proposed). Third-party code keeps its own licence:
`benchmarks/test-tlb/src/test-tlb.c` (see `src/README.upstream`).
