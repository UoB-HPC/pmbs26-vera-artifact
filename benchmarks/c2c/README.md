# Core-to-core latency (Figs. 4-5)

Tool: core-to-core-latency (https://github.com/nviennot/core-to-core-latency),
written in Rust. It pins two threads to two cores and makes them take turns
writing one shared cache line. The time per hand-over is the latency between
those two cores. It repeats this for every pair of cores.

No wrapper script was used; the tool was built and run by hand:

```bash
git clone https://github.com/nviennot/core-to-core-latency
cd core-to-core-latency && cargo build --release
./target/release/core-to-core-latency 1000 --csv > core-to-core-latency.csv
```

The number of samples per iteration was set to 300 within the source code.

## Output

`results/c2c/<platform>/core-to-core-latency.csv` is a lower-triangular
matrix: row i, column j is the latency in ns between core i and core j.
All pairs of the cores of socket 0 were measured, one thread per core.

The gnr and turin-9r45 matrices have 97 rows: the run included one CPU
beyond the 96 cores of socket 0. The figure scripts use the first 96 rows
and columns only; the files are left as written by the tool.
