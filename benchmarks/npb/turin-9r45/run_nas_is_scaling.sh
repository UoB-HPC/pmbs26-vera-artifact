#!/bin/bash
set -euo pipefail

B_DIR=$HOME/joseph/NPB3.4.4/NPB3.4-OMP/bin
RESULTS_DIR=$HOME/turin-results/nas
CSV_FILE="$RESULTS_DIR/nas_is_scaling.out"

CORES=96
exe="$B_DIR/is.D.x"

mkdir -p "$RESULTS_DIR"
[ -f "$CSV_FILE" ] || printf 'kernel,class,cores,mops,runtime_s\n' > "$CSV_FILE"

echo "-----Running IS (Class D, $CORES cores)-----"
output=$(OMP_NUM_THREADS="$CORES" OMP_PROC_BIND=close OMP_PLACES=cores \
	numactl --membind=0 taskset -c "0-$((CORES - 1))" "$exe" 2>&1)

mops=$(printf '%s\n' "$output" | awk -F'=' '/Mop\/s total/ { gsub(/ /,"",$2); print $2 }')
runtime=$(printf '%s\n' "$output" | awk -F'=' '/Time in seconds/ { gsub(/ /,"",$2); print $2 }')

printf '  cores=%s  mops=%s  time=%ss\n' "$CORES" "$mops" "$runtime"
printf 'is,D,%s,%s,%s\n' "$CORES" "$mops" "$runtime" >> "$CSV_FILE"

echo "Done. Results appended to $CSV_FILE"
