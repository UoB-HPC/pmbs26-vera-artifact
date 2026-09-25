#!/bin/bash
set -euo pipefail

# ---- Config: edit these per-machine ----
BINARY=./test-tlb
STRIDE=64
NODE=0                     # numactl node to pin CPU + memory to
LABEL=$(hostname -s)
OUTDIR=results
# -----------------------------------------

SIZES=(4k 8k 16k 32k 64k 128k 256k 512k 1M 2M 4M 6M 8M 16M 32M 64M 128M 256M 512M 1G 2G 4G)
TRIALS=(10 10 10 10 10 10 10 10 10 10 5  5  5  5  5  5  3   3   3   3  3  1)

command -v numactl >/dev/null || { echo "numactl not found" >&2; exit 1; }
[ -x "$BINARY" ] || { echo "$BINARY not found or not executable (did you run make?)" >&2; exit 1; }

mkdir -p "$OUTDIR"
RAW="$OUTDIR/${LABEL}-raw.log"
CSV="$OUTDIR/${LABEL}-avg.csv"

: > "$RAW"
echo "size,trials,mean_ns" > "$CSV"

for i in "${!SIZES[@]}"; do
	size=${SIZES[$i]}
	n=${TRIALS[$i]}
	echo "$size: running $n trial(s)"
	{ echo "=== $size ($n trials, stride=$STRIDE) ==="; } >> "$RAW"

	values=()
	for ((t = 1; t <= n; t++)); do
		out=$(numactl --cpunodebind="$NODE" --membind="$NODE" "$BINARY" -Hr "$size" "$STRIDE")
		echo "$out" >> "$RAW"
		ns=$(sed -E 's/^[[:space:]]*([0-9.]+)ns.*/\1/' <<< "$out")
		values+=("$ns")
	done

	mean=$(printf '%s\n' "${values[@]}" | awk '{sum += $1; n++} END {printf "%.4f", sum/n}')
	echo "$size,$n,$mean" >> "$CSV"
done

echo
echo "Raw runs:  $RAW"
echo "Averages:  $CSV"
