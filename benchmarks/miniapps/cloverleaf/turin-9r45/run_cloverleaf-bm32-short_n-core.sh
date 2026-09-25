#!/usr/bin/env bash
set -euo pipefail

CLOVER_DIR=$HOME/joseph/CloverLeaf_OpenMP
INPUT_DECK="$CLOVER_DIR/InputDecks/clover_bm32_short.in"
RESULTS_DIR=$HOME/turin-results/cloverleaf
RAW_DIR="$RESULTS_DIR/raw"
LOG_FILE="$RESULTS_DIR/cloverleaf-bm32-short-n-core.log"
CSV_FILE="$RESULTS_DIR/cloverleaf-bm32-short-n-core.csv"

mkdir -p "$RAW_DIR"
: > "$LOG_FILE"
printf 'cores,turin\n' > "$CSV_FILE"

cd "$CLOVER_DIR"

for cores in $(seq 1 96); do
	core_end=$((cores - 1))
	cp "$INPUT_DECK" clover.in

	# clover_leaf writes its own step-by-step trace (huge, don't care) to stderr,
	# and a clean summary (including the final "Wall clock" time) to clover.out.
	OMP_NUM_THREADS="$cores" OMP_PROC_BIND=close OMP_PLACES=cores \
		numactl --membind=0 taskset -c "0-$core_end" ./clover_leaf > /dev/null 2>/dev/null

	cp clover.out "$RAW_DIR/clover_${cores}cores.out"

	wallclock=$(awk '/Wall clock/ { val = $3 } END { print val }' clover.out)

	{
		printf '===== cores 0-%s (%s threads) =====\n' "$core_end" "$cores"
		printf 'wall clock: %s\n\n' "$wallclock"
	} | tee -a "$LOG_FILE"

	printf '%s,%s\n' "$cores" "$wallclock" >> "$CSV_FILE"
done

printf 'Done. CSV written to %s\n' "$CSV_FILE"
