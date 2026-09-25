#!/bin/bash
set -euo pipefail

B_DIR=$HOME/joseph/NPB3.4.4/NPB3.4-OMP/bin
RESULTS_DIR=$HOME/turin-results/nas
CSV_FILE="$RESULTS_DIR/nas_scaling.out"

KERNELS=(bt cg ep ft lu mg sp ua)

mkdir -p "$RESULTS_DIR"
printf 'kernel,cores,mops,runtime_s\n' > "$CSV_FILE"

for kernel in "${KERNELS[@]}"; do
	exe="$B_DIR/${kernel}.B.x"
	echo "-----Running ${kernel^^} (Class B)-----"

	for cores in $(seq 1 96); do
		core_end=$((cores - 1))
		output=$(OMP_NUM_THREADS="$cores" OMP_PROC_BIND=close OMP_PLACES=cores \
			numactl --membind=0 taskset -c "0-$core_end" "$exe" 2>&1)

		mops=$(printf '%s\n' "$output" | awk -F'=' '/Mop\/s total/ { gsub(/ /,"",$2); print $2 }')
		runtime=$(printf '%s\n' "$output" | awk -F'=' '/Time in seconds/ { gsub(/ /,"",$2); print $2 }')

		printf '  cores=%s  mops=%s  time=%ss\n' "$cores" "$mops" "$runtime"
		printf '%s,%s,%s,%s\n' "$kernel" "$cores" "$mops" "$runtime" >> "$CSV_FILE"
	done
done

echo "Done. Results written to $CSV_FILE"
