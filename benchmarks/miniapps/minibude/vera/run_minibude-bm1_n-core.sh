#!/usr/bin/env bash
set -euo pipefail

BUDE_EXE="$HOME/joseph/miniBUDE/build/omp-bude"
DECK="$HOME/joseph/miniBUDE/data/bm1"
RESULTS_DIR=$HOME/joseph/results/minibude
RAW_DIR="$RESULTS_DIR/raw"
LOG_FILE="$RESULTS_DIR/minibude-bm1-n-core.log"
CSV_FILE="$RESULTS_DIR/minibude-bm1-n-core.csv"

mkdir -p "$RAW_DIR"
: > "$LOG_FILE"
printf 'cores,sum_ms\n' > "$CSV_FILE"

for cores in $(seq 1 88); do
	core_end=$((cores - 1))
	output=$(OMP_NUM_THREADS="$cores" OMP_PROC_BIND=close OMP_PLACES=cores \
		taskset -c "0-$core_end" "$BUDE_EXE" -i 10 -p 32 --deck "$DECK" 2>/dev/null)

	printf '%s\n' "$output" > "$RAW_DIR/bude_${cores}cores.yaml"

	sum_ms=$(printf '%s\n' "$output" | grep '^best:' | grep -oP 'sum_ms:\s*\K[0-9.]+')

	{
		printf '===== cores 0-%s (%s threads) =====\n' "$core_end" "$cores"
		printf 'sum_ms: %s\n\n' "$sum_ms"
	} | tee -a "$LOG_FILE"

	printf '%s,%s\n' "$cores" "$sum_ms" >> "$CSV_FILE"
done

printf 'Done. CSV written to %s\n' "$CSV_FILE"
