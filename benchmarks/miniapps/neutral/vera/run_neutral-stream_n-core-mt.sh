#!/usr/bin/env bash
set -euo pipefail

NEUTRAL_DIR=$HOME/joseph/arch/neutral
DECK=problems/stream.params
RESULTS_DIR=$HOME/joseph/results/neutral
RAW_DIR="$RESULTS_DIR/raw"
LOG_FILE="$RESULTS_DIR/neutral-stream-n-core-mt.log"
CSV_FILE="$RESULTS_DIR/neutral-stream-n-core-mt.csv"

mkdir -p "$RAW_DIR"
: > "$LOG_FILE"
printf 'cores,threads,wallclock_s\n' > "$CSV_FILE"

cd "$NEUTRAL_DIR"

for cores in $(seq 1 88); do
	# Each step adds one more physical core's pair of SMT threads:
	# core N's two hardware threads are logical CPUs N and N+88.
	core_end=$((cores - 1))
	sibling_start=88
	sibling_end=$((87 + cores))
	threads=$((cores * 2))

	output=$(OMP_NUM_THREADS="$threads" OMP_PROC_BIND=close OMP_PLACES=cores \
		taskset -c "0-$core_end,$sibling_start-$sibling_end" ./neutral.omp3 "$DECK" 2>/dev/null)

	printf '%s\n' "$output" > "$RAW_DIR/neutral_${cores}cores_mt.log"

	wallclock=$(printf '%s\n' "$output" | grep -oP 'Final Wallclock \K[0-9.]+')

	{
		printf '===== cores 0-%s,%s-%s (%s threads) =====\n' "$core_end" "$sibling_start" "$sibling_end" "$threads"
		printf 'wallclock: %s\n\n' "$wallclock"
	} | tee -a "$LOG_FILE"

	printf '%s,%s,%s\n' "$cores" "$threads" "$wallclock" >> "$CSV_FILE"
done

printf 'Done. CSV written to %s\n' "$CSV_FILE"
