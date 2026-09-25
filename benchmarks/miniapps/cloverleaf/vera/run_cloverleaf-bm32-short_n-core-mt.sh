#!/usr/bin/env bash
set -euo pipefail

CLOVER_DIR=$HOME/joseph/CloverLeaf_OpenMP
INPUT_DECK="$CLOVER_DIR/InputDecks/clover_bm32_short.in"
RESULTS_DIR=$HOME/joseph/results/cloverleaf
RAW_DIR="$RESULTS_DIR/raw"
LOG_FILE="$RESULTS_DIR/cloverleaf-bm32-short-n-core-mt.log"
CSV_FILE="$RESULTS_DIR/cloverleaf-bm32-short-n-core-mt.csv"

mkdir -p "$RAW_DIR"
: > "$LOG_FILE"
printf 'cores,threads,vera\n' > "$CSV_FILE"

cd "$CLOVER_DIR"

for cores in $(seq 1 88); do
	# Each step adds one more physical core's pair of SMT threads:
	# core N's two hardware threads are logical CPUs N and N+88.
	core_end=$((cores - 1))
	sibling_start=88
	sibling_end=$((87 + cores))
	threads=$((cores * 2))

	cp "$INPUT_DECK" clover.in

	# clover_leaf writes its own step-by-step trace (huge, don't care) to stderr,
	# and a clean summary (including the final "Wall clock" time) to clover.out.
	OMP_NUM_THREADS="$threads" OMP_PROC_BIND=close OMP_PLACES=cores \
		taskset -c "0-$core_end,$sibling_start-$sibling_end" ./clover_leaf > /dev/null 2>/dev/null

	cp clover.out "$RAW_DIR/clover_${cores}cores_mt.out"

	vera=$(awk '/Wall clock/ { val = $3 } END { print val }' clover.out)

	{
		printf '===== cores 0-%s,%s-%s (%s threads) =====\n' "$core_end" "$sibling_start" "$sibling_end" "$threads"
		printf 'wall clock: %s\n\n' "$vera"
	} | tee -a "$LOG_FILE"

	printf '%s,%s,%s\n' "$cores" "$threads" "$vera" >> "$CSV_FILE"
done

printf 'Done. CSV written to %s\n' "$CSV_FILE"
