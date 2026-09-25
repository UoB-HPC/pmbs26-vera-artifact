#!/bin/bash
#SBATCH --job-name=cloverleaf-grace
#SBATCH --partition=grace
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --exclusive
#SBATCH --time=02:00:00
#SBATCH --output=$HOME/grace-gcc-15/grace-results/cloverleaf/slurm-%j.out
#SBATCH --error=$HOME/grace-gcc-15/grace-results/cloverleaf/slurm-%j.out

set -euo pipefail

# Single-socket pinning: socket 0 == NUMA node 0 == cpus 0-71 on this Grace node.
SOCKET=0
SOCKET_LAST_CPU=71

source "$HOME/tools/gcc-15.3.0/activate.sh"

CLOVER_DIR="$HOME/grace-gcc-15/CloverLeaf_OpenMP"
INPUT_DECK="$CLOVER_DIR/InputDecks/clover_bm32_short.in"
RESULTS_DIR="$HOME/grace-gcc-15/grace-results/cloverleaf"
RAW_DIR="$RESULTS_DIR/raw"
LOG_FILE="$RESULTS_DIR/cloverleaf-bm32-short-n-core.log"
CSV_FILE="$RESULTS_DIR/cloverleaf-bm32-short-n-core.csv"

mkdir -p "$RAW_DIR"
: > "$LOG_FILE"
printf 'cores,grace\n' > "$CSV_FILE"

cd "$CLOVER_DIR"

for cores in $(seq 1 "$((SOCKET_LAST_CPU + 1))"); do
	core_end=$((cores - 1))
	cp "$INPUT_DECK" clover.in

	OMP_NUM_THREADS="$cores" OMP_PROC_BIND=close OMP_PLACES=cores \
		numactl --cpunodebind="$SOCKET" --membind="$SOCKET" \
		taskset -c "0-$core_end" ./clover_leaf > /dev/null 2>/dev/null

	cp clover.out "$RAW_DIR/clover_${cores}cores.out"

	grace=$(awk '/Wall clock/ { val = $3 } END { print val }' clover.out)

	{
		printf '===== cores 0-%s (%s threads) =====\n' "$core_end" "$cores"
		printf 'wall clock: %s\n\n' "$grace"
	} | tee -a "$LOG_FILE"

	printf '%s,%s\n' "$cores" "$grace" >> "$CSV_FILE"
done

printf 'Done. CSV written to %s\n' "$CSV_FILE"
