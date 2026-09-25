# test-tlb (Fig. 3)

Memory access latency for region sizes from 4 KiB to 4 GiB.
Tool: test-tlb by Linus Torvalds (https://github.com/torvalds/test-tlb).
`src/` holds the copy used, with its upstream README.

## Build

```bash
cd src && make        # gcc -g -Wall -O test-tlb.c -o test-tlb -lm
```

`PAGE_SIZE` at the top of `test-tlb.c` must match the base page size of the
system. The copy here is set to `16*4096` (64 KiB), the base page size of the
Vera and Grace kernels. The x86 systems use 4 KiB pages (`4096`).

## Run

```bash
cp src/test-tlb . && ./run-avg.sh
```

`run-avg.sh` runs, for each of 22 region sizes (4k ... 4G),

```
numactl --cpunodebind=0 --membind=0 ./test-tlb -Hr <size> 64
```

- `-H`: back the region with 2 MiB transparent huge pages, so the result
  shows cache latency and not TLB misses.
- `-r`: random pointer-chase order, which defeats the stride prefetchers.
- `64`: 64-byte spacing between chain entries (one cache line).

It repeats each size 10 times (4k-2M), 5 times (4M-64M), 3 times
(128M-2G) or once (4G) and writes the mean to `<host>-avg.csv`
(`size,trials,mean_ns`) and every trial to `<host>-raw.log`. These are
`results/test-tlb/<platform>/latencies-rand-huge-avg.csv` and `-raw.log`.
