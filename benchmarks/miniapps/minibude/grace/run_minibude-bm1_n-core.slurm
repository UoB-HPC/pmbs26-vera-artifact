#!/bin/bash
#SBATCH --job-name=minibude-grace
#SBATCH --partition=grace
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --exclusive
#SBATCH --time=02:00:00
#SBATCH --output=$HOME/grace-gcc-15/grace-results/minibude/slurm-%j.out
#SBATCH --error=$HOME/grace-gcc-15/grace-results/minibude/slurm-%j.out

set -euo pipefail

# Single-socket pinning: socket 0 == NUMA node 0 == cpus 0-71 on this Grace node.
SOCKET=0
SOCKET_LAST_CPU=71

source "$HOME/tools/gcc-15.3.0/activate.sh"

BUDE_EXE="$HOME/grace-gcc-15/miniBUDE/build/omp-bude"
DECK="$HOME/grace-gcc-15/miniBUDE/data/bm1"
RESULTS_DIR="$HOME/grace-gcc-15/grace-results/minibude"
RAW_DIR="$RESULTS_DIR/raw"
LOG_FILE="$RESULTS_DIR/minibude-bm1-n-core.log"
CSV_FILE="$RESULTS_DIR/minibude-bm1-n-core.csv"

mkdir -p "$RAW_DIR"
: > "$LOG_FILE"
printf 'cores,sum_ms\n' > "$CSV_FILE"

for cores in $(seq 1 "$((SOCKET_LAST_CPU + 1))"); do
	core_end=$((cores - 1))
	output=$(OMP_NUM_THREADS="$cores" OMP_PROC_BIND=close OMP_PLACES=cores \
		numactl --cpunodebind="$SOCKET" --membind="$SOCKET" \
		taskset -c "0-$core_end" "$BUDE_EXE" -i 10 -p 32 --deck "$DECK" 2>/dev/null)

	printf '%s\n' "$output" > "$RAW_DIR/bude_${cores}cores.yaml"

	sum_ms=$(printf '%s\n' "$output" | grep '^best:' | grep -oP 'sum_ms:\s*\K[0-9.]+')

	{
		printf '===== cores 0-%s (%s threads) =====\n' "$core_end" "$cores"
		printf 'sum_ms: %s\n\n' "$sum_ms"
	} | tee -a "$LOG_FILE"

	printf '%s,%s\n' "$cores" "$sum_ms" >> "$CSV_FILE"
done

printf 'Done. CSV written to %s\n' "$CSV_FILE"
