#!/usr/bin/env bash
set -euo pipefail

BUDE_EXE="$HOME/joseph/miniBUDE/build/omp-bude"
DECK="$HOME/joseph/miniBUDE/data/bm1"
RESULTS_DIR=$HOME/joseph/results/minibude
RAW_DIR="$RESULTS_DIR/raw"
LOG_FILE="$RESULTS_DIR/minibude-bm1-n-core-mt.log"
CSV_FILE="$RESULTS_DIR/minibude-bm1-n-core-mt.csv"

mkdir -p "$RAW_DIR"
: > "$LOG_FILE"
printf 'cores,threads,sum_ms\n' > "$CSV_FILE"

for cores in $(seq 1 88); do
	# Each step adds one more physical core's pair of SMT threads:
	# core N's two hardware threads are logical CPUs N and N+88.
	core_end=$((cores - 1))
	sibling_start=88
	sibling_end=$((87 + cores))
	threads=$((cores * 2))

	output=$(OMP_NUM_THREADS="$threads" OMP_PROC_BIND=close OMP_PLACES=cores \
		taskset -c "0-$core_end,$sibling_start-$sibling_end" "$BUDE_EXE" -i 10 -p 32 --deck "$DECK" 2>/dev/null)

	printf '%s\n' "$output" > "$RAW_DIR/bude_${cores}cores_mt.yaml"

	sum_ms=$(printf '%s\n' "$output" | grep '^best:' | grep -oP 'sum_ms:\s*\K[0-9.]+')

	{
		printf '===== cores 0-%s,%s-%s (%s threads) =====\n' "$core_end" "$sibling_start" "$sibling_end" "$threads"
		printf 'sum_ms: %s\n\n' "$sum_ms"
	} | tee -a "$LOG_FILE"

	printf '%s,%s,%s\n' "$cores" "$threads" "$sum_ms" >> "$CSV_FILE"
done

printf 'Done. CSV written to %s\n' "$CSV_FILE"
