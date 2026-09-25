#!/bin/bash
#SBATCH --job-name=nas-scaling-grace
#SBATCH --partition=grace
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --exclusive
#SBATCH --time=06:00:00
#SBATCH --output=$HOME/grace-gcc-15/grace-results/nas/slurm-scaling-%j.out
#SBATCH --error=$HOME/grace-gcc-15/grace-results/nas/slurm-scaling-%j.out

set -euo pipefail

# Single-socket pinning: socket 0 == NUMA node 0 == cpus 0-71 on this Grace node.
SOCKET=0
SOCKET_LAST_CPU=71

# Work arrays (e.g. FT's per-thread FFT scratch space, sized off maxdim) don't fit in
# the default OpenMP worker-thread stack - see NPB3.4-OMP/README.install.
# ulimit -s only covers the main thread; libgomp worker threads need OMP_STACKSIZE set explicitly.
ulimit -s unlimited
export OMP_STACKSIZE=512M

source "$HOME/tools/gcc-15.3.0/activate.sh"

B_DIR="$HOME/grace-gcc-15/NPB3.4.4/NPB3.4-OMP/bin"
RESULTS_DIR="$HOME/grace-gcc-15/grace-results/nas"
RAW_DIR="$RESULTS_DIR/raw"
LOG_FILE="$RESULTS_DIR/nas-classB-n-core.log"
CSV_FILE="$RESULTS_DIR/nas-classB-n-core.csv"

KERNELS=(bt cg ep ft is lu mg sp ua)

mkdir -p "$RAW_DIR"
: > "$LOG_FILE"
printf 'kernel,cores,mops,runtime_s\n' > "$CSV_FILE"

for kernel in "${KERNELS[@]}"; do
	exe="$B_DIR/${kernel}.B.x"
	echo "-----Running ${kernel^^} (Class B)-----" | tee -a "$LOG_FILE"

	for cores in $(seq 1 "$((SOCKET_LAST_CPU + 1))"); do
		core_end=$((cores - 1))
		output=$(OMP_NUM_THREADS="$cores" OMP_PROC_BIND=close OMP_PLACES=cores \
			numactl --cpunodebind="$SOCKET" --membind="$SOCKET" \
			taskset -c "0-$core_end" "$exe" 2>&1)

		printf '%s\n' "$output" > "$RAW_DIR/${kernel}_${cores}cores.log"

		mops=$(printf '%s\n' "$output" | awk -F'=' '/Mop\/s total/ { gsub(/ /,"",$2); print $2 }')
		runtime=$(printf '%s\n' "$output" | awk -F'=' '/Time in seconds/ { gsub(/ /,"",$2); print $2 }')

		printf '  cores=%s  mops=%s  time=%ss\n' "$cores" "$mops" "$runtime" | tee -a "$LOG_FILE"
		printf '%s,%s,%s,%s\n' "$kernel" "$cores" "$mops" "$runtime" >> "$CSV_FILE"
	done
done

printf 'Done. CSV written to %s\n' "$CSV_FILE"
