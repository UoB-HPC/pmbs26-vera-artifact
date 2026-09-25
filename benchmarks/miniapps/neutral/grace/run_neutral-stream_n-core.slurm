#!/bin/bash
#SBATCH --job-name=neutral-grace
#SBATCH --partition=grace
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --exclusive
#SBATCH --time=02:00:00
#SBATCH --output=$HOME/grace-gcc-15/grace-results/neutral/slurm-%j.out
#SBATCH --error=$HOME/grace-gcc-15/grace-results/neutral/slurm-%j.out

set -euo pipefail

# Single-socket pinning: socket 0 == NUMA node 0 == cpus 0-71 on this Grace node.
SOCKET=0
SOCKET_LAST_CPU=71

source "$HOME/tools/gcc-15.3.0/activate.sh"

NEUTRAL_DIR="$HOME/grace-gcc-15/arch/neutral"
DECK=problems/stream.params
RESULTS_DIR="$HOME/grace-gcc-15/grace-results/neutral"
RAW_DIR="$RESULTS_DIR/raw"
LOG_FILE="$RESULTS_DIR/neutral-stream-n-core.log"
CSV_FILE="$RESULTS_DIR/neutral-stream-n-core.csv"

mkdir -p "$RAW_DIR"
: > "$LOG_FILE"
printf 'cores,wallclock_s\n' > "$CSV_FILE"

cd "$NEUTRAL_DIR"

for cores in $(seq 1 "$((SOCKET_LAST_CPU + 1))"); do
	core_end=$((cores - 1))
	output=$(OMP_NUM_THREADS="$cores" OMP_PROC_BIND=close OMP_PLACES=cores \
		numactl --cpunodebind="$SOCKET" --membind="$SOCKET" \
		taskset -c "0-$core_end" ./neutral.omp3 "$DECK" 2>/dev/null)

	printf '%s\n' "$output" > "$RAW_DIR/neutral_${cores}cores.log"

	wallclock=$(printf '%s\n' "$output" | grep -oP 'Final Wallclock \K[0-9.]+')

	{
		printf '===== cores 0-%s (%s threads) =====\n' "$core_end" "$cores"
		printf 'wallclock: %s\n\n' "$wallclock"
	} | tee -a "$LOG_FILE"

	printf '%s,%s\n' "$cores" "$wallclock" >> "$CSV_FILE"
done

printf 'Done. CSV written to %s\n' "$CSV_FILE"
