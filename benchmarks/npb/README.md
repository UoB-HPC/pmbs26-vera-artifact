# NAS Parallel Benchmarks (Figs. 6-8)

NPB 3.4.4, OpenMP version (`NPB3.4-OMP`, https://www.nas.nasa.gov/software/npb.html),
kernels BT CG EP FT IS LU MG SP UA. Class D for whole-chip runs (Figs. 6, 8),
class B for the core sweeps (Fig. 7).

## Build

GCC 15.3.0 (`gfortran`, `gcc` for IS). Edit `config/make.def`, then
`make <kernel> CLASS=<B|D>`. The flags below are copied from the
"Compile options" block that every NPB binary prints (see
`results/npb/<platform>/raw/`).

| platform | `FFLAGS` / `CFLAGS` |
|---|---|
| vera | `-O3 -fopenmp -mcpu=olympus -mcmodel=large ...` (NPB truncates the line; TODO(npb-flags): full Vera flags) |
| grace | `-O3 -fopenmp -mcpu=neoverse-v2` (from the class B output `raw/bt-B-72cores.log`; the class D log has no compile block) |
| turin-9r45, gnr | `-O3 -fopenmp -march=native -mcmodel=large` |

Exception on both x86 platforms: the class D **EP** and **LU** binaries were
built earlier, with `-O3 -fopenmp` only (no `-march=native`, no
`-mcmodel=large`). This is visible in `raw/nas-D.out` (compile date and
flags). All other x86 class D binaries use the flags in the table.
TODO(npb-flags): class B flags per platform.

## Run

| script | what | placement |
|---|---|---|
| `run_nas.sh` | class D, whole chip, one thread per core | `OMP_PROC_BIND=close taskset -c 0-(N-1)` |
| `run_nas_mt.sh` (vera) | class D, SMT on, 176 threads | `taskset -c 0-175` (all hardware threads) |
| `run_nas_scaling.sh` | class B, 1..N cores | `OMP_PROC_BIND=close OMP_PLACES=cores taskset -c 0-(n-1)` |
| `run_nas_mt_scaling.sh` | class B, 1..N cores, 2 threads per core | cores 0..n-1 plus their siblings |
| `run_is_*.sh`, `run_nas_is_scaling.sh` | IS only (added to the harness later) | as above |

- turin-9r45 adds `numactl --membind=0` (two-socket instance).
- grace runs under Slurm (`*.slurm`) with
  `numactl --cpunodebind=0 --membind=0`, `ulimit -s unlimited` and
  `OMP_STACKSIZE=512M`. The other platforms do not set `OMP_STACKSIZE` in
  their scripts.
- Each configuration was run once.

Figure of merit: `Mop/s total` from the NPB output. `scripts/parse/npb.py`
reads `results/npb/<platform>/` into `data/npb/nas-D.csv` and
`data/npb/nas-scaling.csv`.
