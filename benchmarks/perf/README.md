# perf stat counters (Sec. V)

`run_perf_stats.sh` runs the NAS kernels (classes B and D), the miniapps and
STREAM once each on the whole chip under

```
perf stat --no-big-num -e task-clock,cycles,instructions,branches,branch-misses,
  cache-references,cache-misses,L1-dcache-loads,L1-dcache-load-misses,
  L1-icache-load-misses,LLC-loads,LLC-load-misses,dTLB-loads,dTLB-load-misses,
  iTLB-loads,iTLB-load-misses,context-switches,cpu-migrations,page-faults
```

and writes `perf_events.csv` (raw counts) and `perf_app_metrics.csv`
(ratios such as IPC and miss rates). These are
`results/perf/<platform>/events.csv` and `app-metrics.csv`.
`run_perf_stats_mt.sh` (vera) repeats this with SMT on.
`setup_perf_perms.sh` lowers `perf_event_paranoid` so a normal user can
count events (needs sudo).

The paper quotes ratios only. The generic event names map to different
hardware events on each vendor, so raw counts are not compared across
platforms. There is no perf data for Grace.
