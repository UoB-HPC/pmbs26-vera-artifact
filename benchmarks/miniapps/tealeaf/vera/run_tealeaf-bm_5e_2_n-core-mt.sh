#!/usr/bin/env bash
set -euo pipefail

TEALEAF_DIR=$HOME/joseph/tealeaf
INPUT_DECK="$TEALEAF_DIR/Benchmarks/tea_bm_5e_2.in"
RESULTS_DIR=$HOME/joseph/results/tealeaf
RAW_DIR="$RESULTS_DIR/raw"
LOG_FILE="$RESULTS_DIR/tealeaf-bm_5e_2-n-core-mt.log"
CSV_FILE="$RESULTS_DIR/tealeaf-bm_5e_2-n-core-mt.csv"

mkdir -p "$RAW_DIR"
: > "$LOG_FILE"
printf 'cores,threads,wallclock_s\n' > "$CSV_FILE"

cd "$TEALEAF_DIR"

for cores in $(seq 1 88); do
	# Each step adds one more physical core's pair of SMT threads:
	# core N's two hardware threads are logical CPUs N and N+88.
	core_end=$((cores - 1))
	sibling_start=88
	sibling_end=$((87 + cores))
	threads=$((cores * 2))

	cp "$INPUT_DECK" tea.in

	OMP_NUM_THREADS="$threads" OMP_PROC_BIND=close OMP_PLACES=cores \
		taskset -c "0-$core_end,$sibling_start-$sibling_end" ./build/omp-tealeaf > /dev/null 2>/dev/null

	cp tea.out "$RAW_DIR/tea_${cores}cores_mt.out"

	wallclock=$(grep -oP 'Wallclock:\s*\K[0-9.]+' tea.out | tail -1)

	{
		printf '===== cores 0-%s,%s-%s (%s threads) =====\n' "$core_end" "$sibling_start" "$sibling_end" "$threads"
		printf 'wallclock: %s\n\n' "$wallclock"
	} | tee -a "$LOG_FILE"

	printf '%s,%s,%s\n' "$cores" "$threads" "$wallclock" >> "$CSV_FILE"
done

printf 'Done. CSV written to %s\n' "$CSV_FILE"
