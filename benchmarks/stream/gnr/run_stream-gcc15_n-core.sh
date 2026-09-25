#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH=$HOME/joseph/STREAM
RESULTS_DIR=$HOME/gnr-results/stream
LOG_FILE="$RESULTS_DIR/stream-n-core-gcc15.txt"
CSV_FILE="$RESULTS_DIR/stream-n-core-gcc15.csv"

mkdir -p "$RESULTS_DIR"
: > "$LOG_FILE"
printf 'cores,copy_mb_s,scale_mb_s,add_mb_s,triad_mb_s\n' > "$CSV_FILE"

cd "$SOURCE_PATH"

for cores in $(seq 1 96); do
	core_end=$((cores - 1))
	output=$(OMP_NUM_THREADS="$cores" OMP_PROC_BIND=spread OMP_PLACES=cores taskset -c "0-$core_end" ./stream_c.exe)

	{
		printf '===== cores 0-%s (%s threads) =====\n' "$core_end" "$cores"
		printf '%s\n' "$output"
		printf '\n'
	} | tee -a "$LOG_FILE"

	printf '%s\n' "$output" | awk -v cores="$cores" '
		/^Copy:/ { copy = $2 }
		/^Scale:/ { scale = $2 }
		/^Add:/ { add = $2 }
		/^Triad:/ { triad = $2 }
		END { printf "%s,%s,%s,%s,%s\n", cores, copy, scale, add, triad }
	' >> "$CSV_FILE"
done

