#!/usr/bin/env bash
set -euo pipefail

TEALEAF_DIR=$HOME/joseph/tealeaf
INPUT_DECK="$TEALEAF_DIR/Benchmarks/tea_bm_5e_2.in"
RESULTS_DIR=$HOME/joseph/results/tealeaf
RAW_DIR="$RESULTS_DIR/raw"
LOG_FILE="$RESULTS_DIR/tealeaf-bm_5e_2-n-core.log"
CSV_FILE="$RESULTS_DIR/tealeaf-bm_5e_2-n-core.csv"

mkdir -p "$RAW_DIR"
: > "$LOG_FILE"
printf 'cores,wallclock_s\n' > "$CSV_FILE"

cd "$TEALEAF_DIR"

for cores in $(seq 1 88); do
	core_end=$((cores - 1))
	cp "$INPUT_DECK" tea.in

	OMP_NUM_THREADS="$cores" OMP_PROC_BIND=close OMP_PLACES=cores \
		taskset -c "0-$core_end" ./build/omp-tealeaf > /dev/null 2>/dev/null

	cp tea.out "$RAW_DIR/tea_${cores}cores.out"

	wallclock=$(grep -oP 'Wallclock:\s*\K[0-9.]+' tea.out | tail -1)

	{
		printf '===== cores 0-%s (%s threads) =====\n' "$core_end" "$cores"
		printf 'wallclock: %s\n\n' "$wallclock"
	} | tee -a "$LOG_FILE"

	printf '%s,%s\n' "$cores" "$wallclock" >> "$CSV_FILE"
done

printf 'Done. CSV written to %s\n' "$CSV_FILE"
