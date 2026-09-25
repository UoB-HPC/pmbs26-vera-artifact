# STREAM (Fig. 2)

STREAM 5.10 (`stream.c` from https://www.cs.virginia.edu/stream/FTP/Code/),
OpenMP, GCC 15.3.0. Put `stream.c` in `$HOME/joseph/STREAM` (or edit
`SOURCE_PATH` at the top of each script), then per platform:

```bash
./build_stream-gcc15.sh             # make -f Makefile-gcc15
./run_stream-gcc15.sh               # whole chip  -> full-cores-best.txt
./run_stream-gcc15_n-core.sh        # 1..N cores, sequential order -> scaling-sequential.csv
./run_stream-gcc15_n-core_rr.sh     # 1..N cores, round-robin      -> scaling-round-robin.csv (Fig. 2)
```

## Build settings (from `Makefile-gcc15`)

Common: `-O3 -fopenmp -mcmodel=large -fno-pie -no-pie -ffreestanding -DNTIMES=100`.

| platform | `STREAM_ARRAY_SIZE` (8-byte elements) | memory per array | arch flag |
|---|---|---|---|
| vera | 183,000,000 | 1.4 GiB | `-mcpu=olympus -mno-outline-atomics` |
| grace | 240,000,000 | 1.8 GiB | `-mcpu=neoverse-v2` |
| turin-9r45 | 202,000,000 | 1.5 GiB | `-march=native` |
| gnr | 252,000,000 | 1.9 GiB | `-march=native` |

Each array is at least 4x the last-level cache. STREAM reports the best of
100 iterations (the first is excluded).

## Run settings

- `OMP_NUM_THREADS=<cores> OMP_PROC_BIND=spread OMP_PLACES=cores taskset -c <list>`.
- Sequential sweep: cores `0..n-1`.
- Round-robin sweep: cores taken with a stride of 8 (`0,8,16,...,1,9,17,...`),
  so that each added core lands in a different part of the chip.
- turin-9r45 also uses `numactl --membind=0` (the instance has two sockets).

## Grace

For Grace, the same script can be used as for other architectures but with the following parameters:
- Built using `-mcpu=neoverse-v2`
- Array size = 240,000,000
- Iterations = 100
- OMP_NUM_THREADS = 72
