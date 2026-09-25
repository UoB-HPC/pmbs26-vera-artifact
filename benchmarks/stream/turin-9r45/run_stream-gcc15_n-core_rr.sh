#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH=$HOME/joseph/STREAM
RESULTS_DIR=$HOME/turin-results/stream
LOG_FILE="$RESULTS_DIR/stream-n-core-rr-gcc15.txt"
CSV_FILE="$RESULTS_DIR/stream-n-core-rr-gcc15.csv"

mkdir -p "$RESULTS_DIR"
: > "$LOG_FILE"
printf 'cores,copy_mb_s,scale_mb_s,add_mb_s,triad_mb_s\n' > "$CSV_FILE"

cd "$SOURCE_PATH"

build_rr_core_list() {
	local count="$1"
	local stride=8
	local total_cores=96
	local -a cores=()
	local offset core

	for ((offset = 0; offset < stride; offset++)); do
		for ((core = offset; core < total_cores; core += stride)); do
			cores+=("$core")
			if (( ${#cores[@]} >= count )); then
				local IFS=,
				printf '%s\n' "${cores[*]}"
				return
			fi
		done
	done
}

for cores in $(seq 1 96); do
	core_list=$(build_rr_core_list "$cores")
	output=$(OMP_NUM_THREADS="$cores" OMP_PROC_BIND=spread OMP_PLACES=cores numactl --membind=0 taskset -c "$core_list" ./stream_c.exe)

	{
		printf '===== cores %s (%s threads) =====\n' "$core_list" "$cores"
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

