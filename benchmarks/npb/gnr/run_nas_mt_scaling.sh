#!/bin/bash
set -euo pipefail

B_DIR=$HOME/joseph/NPB3.4.4/NPB3.4-OMP/bin
RESULTS_DIR=$HOME/gnr-results/nas
CSV_FILE="$RESULTS_DIR/nas_mt_scaling.out"

KERNELS=(bt cg ep ft is lu mg sp ua)

mkdir -p "$RESULTS_DIR"
printf 'kernel,cores,threads,mops,runtime_s\n' > "$CSV_FILE"

for kernel in "${KERNELS[@]}"; do
	exe="$B_DIR/${kernel}.B.x"
	echo "-----Running ${kernel^^} (Class B)-----"

	for cores in $(seq 1 96); do
		# Each step adds one more physical core's pair of SMT threads:
		# core N's two hardware threads are logical CPUs N and N+96.
		core_end=$((cores - 1))
		sibling_start=96
		sibling_end=$((95 + cores))
		threads=$((cores * 2))

		output=$(OMP_NUM_THREADS="$threads" OMP_PROC_BIND=close OMP_PLACES=cores \
			taskset -c "0-$core_end,$sibling_start-$sibling_end" "$exe" 2>&1)

		mops=$(printf '%s\n' "$output" | awk -F'=' '/Mop\/s total/ { gsub(/ /,"",$2); print $2 }')
		runtime=$(printf '%s\n' "$output" | awk -F'=' '/Time in seconds/ { gsub(/ /,"",$2); print $2 }')

		printf '  cores=%s  threads=%s  mops=%s  time=%ss\n' "$cores" "$threads" "$mops" "$runtime"
		printf '%s,%s,%s,%s,%s\n' "$kernel" "$cores" "$threads" "$mops" "$runtime" >> "$CSV_FILE"
	done
done

echo "Done. Results written to $CSV_FILE"
