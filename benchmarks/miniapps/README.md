# Miniapps (Figs. 9-10)

Four OpenMP miniapps, each swept over 1..N cores of socket 0. Fig. 9 uses
the whole-chip point; Fig. 10 plots the whole sweep. Vera also has SMT-on
sweeps (`*-mt.sh`, two threads per core).

| app | source | input | binary |
|---|---|---|---|
| CloverLeaf | https://github.com/UK-MAC/CloverLeaf_OpenMP | `InputDecks/clover_bm32_short.in` | `clover_leaf` |
| TeaLeaf | https://github.com/UoB-HPC/TeaLeaf (OpenMP model, CMake) | `Benchmarks/tea_bm_5e_2.in` | `build/omp-tealeaf` |
| Neutral | https://github.com/UoB-HPC/arch (`neutral/`, OpenMP 3 kernels) | `problems/stream.params` | `neutral.omp3` |
| miniBUDE | https://github.com/UoB-HPC/miniBUDE (OpenMP model, CMake) | `data/bm1` | `build/omp-bude` |

## Build

GCC 15.3.0, `-O3`, arch flag `-mcpu=olympus` (Vera), `-mcpu=neoverse-v2`
(Grace), `-march=native` (x86).

- miniBUDE, commit `570f66c1fd0c29b7f3ab6fa96fba87f4561aa44c`, CMake
  `MODEL=omp`. Compile line recorded by miniBUDE itself (in
  `results/miniapps/<platform>/minibude-bm1-<N>cores.yaml`):
  `c++ -DOMP -std=c++17 -O3 -ffast-math <arch flag> -fopenmp`.
  Note: `build-gcc15.sh` in this folder is an older Makefile build and does
  not match the CMake binary the run scripts call.
- CloverLeaf, TeaLeaf, Neutral: build commands and
  commits.

## Run

All sweeps: for n = 1..N, `OMP_NUM_THREADS=n OMP_PROC_BIND=close
OMP_PLACES=cores taskset -c 0-(n-1)`. SMT sweeps add the sibling hardware
threads (`taskset -c 0-(n-1),88-(87+n)`, 2n threads). grace runs under Slurm
with `numactl --cpunodebind=0 --membind=0`; turin-9r45 adds
`numactl --membind=0`.

Each configuration was run once, except miniBUDE (see below).

### miniBUDE final configuration

The data in the paper uses the following common settings: deck `bm1`, `-p 32` (32 poses per work item) and
`-i 100` (100 iterations). With 65,536 poses, `-p 32` gives 2,048 work
items, at least 21 per thread on every chip, so no thread is left idle at
the end of an iteration. The whole-chip YAML output of the final run is in `results/miniapps/<platform>/`
and records the commit, compile line, iterations, `ppwi` and every iteration
time.

Figure of merit: wall time. CloverLeaf, TeaLeaf and Neutral report their
own run time; miniBUDE uses `sum_ms`, the sum of the 100 iteration times.
`scripts/parse/miniapps.py` converts all four to seconds in
`data/miniapps/scaling.csv`.
