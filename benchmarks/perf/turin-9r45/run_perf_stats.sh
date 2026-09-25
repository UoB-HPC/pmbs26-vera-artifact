#!/usr/bin/env bash
# Collects `perf stat` hardware/software counters (cache misses, branch
# misses, TLB misses, cycles, instructions, etc.) for one full-core run
# (1 thread per physical core, no SMT) of every miniapp, plus every NAS
# kernel at Class D. This is a separate, one-shot profiling pass -- it does
# not do any core-count scaling; see scripts/nas/run_nas_scaling.sh and the
# per-app run_*_n-core.sh scripts for that.
#
# ==== PORTING TO ANOTHER MACHINE/ARCHITECTURE ====
# - Physical core count is auto-detected below; nothing to change there.
# - PERF_EVENTS below uses only perf's architecture-generic event names
#   (the same names resolve to the right PMU events on x86, arm64, etc.),
#   so the event list itself should not need to change. Any event a given
#   CPU/PMU doesn't support just comes back as "<not supported>" in the
#   raw log and "NA" in the CSV -- it won't abort the run.
# - The APP_* path variables below point at this machine's build/install
#   locations and will need updating on another machine.
# - Unprivileged `perf stat` requires perf_event_paranoid access; run
#   scripts/perf/setup_perf_perms.sh once per machine first if this script's
#   preflight check fails.
set -euo pipefail

RESULTS_DIR=$HOME/turin-results/perf
RAW_DIR="$RESULTS_DIR/raw"
EVENTS_CSV="$RESULTS_DIR/perf_events.csv"
METRICS_CSV="$RESULTS_DIR/perf_app_metrics.csv"

THREADS_PER_CORE=$(lscpu | awk -F: '/Thread\(s\) per core/ { gsub(/ /,"",$2); print $2 }')
CORES=$(( $(nproc --all) / THREADS_PER_CORE ))
CORE_END=$((CORES - 1))
CPU_RANGE="0-$CORE_END"

# Generic hardware + software events, portable across PMUs/architectures.
# Deliberately limited to what perf standardizes (L1 + last-level cache;
# finer levels like L2 have no portable generic name and need per-arch raw
# event codes).
PERF_EVENTS="task-clock,cycles,instructions,branches,branch-misses,"
PERF_EVENTS+="cache-references,cache-misses,"
PERF_EVENTS+="L1-dcache-loads,L1-dcache-load-misses,L1-icache-load-misses,"
PERF_EVENTS+="LLC-loads,LLC-load-misses,"
PERF_EVENTS+="dTLB-loads,dTLB-load-misses,iTLB-loads,iTLB-load-misses,"
PERF_EVENTS+="context-switches,cpu-migrations,page-faults"

NAS_BIN_DIR=$HOME/joseph/NPB3.4.4/NPB3.4-OMP/bin
NAS_KERNELS=(bt cg ep ft is lu mg sp ua)
NAS_CLASSES=(B D)

CLOVER_DIR=$HOME/joseph/CloverLeaf_OpenMP
CLOVER_DECK="$CLOVER_DIR/InputDecks/clover_bm32_short.in"

BUDE_EXE="$HOME/joseph/miniBUDE/build/omp-bude"
BUDE_DECK="$HOME/joseph/miniBUDE/data/bm1"

NEUTRAL_DIR=$HOME/joseph/arch/neutral
NEUTRAL_DECK=problems/stream.params

TEALEAF_DIR=$HOME/joseph/tealeaf
TEALEAF_DECK="$TEALEAF_DIR/Benchmarks/tea_bm_5e_2.in"

STREAM_DIR=$HOME/joseph/STREAM

mkdir -p "$RAW_DIR"
printf 'app,cores,threads,event,value\n' > "$EVENTS_CSV"
printf 'app,cores,threads,metric,value\n' > "$METRICS_CSV"

preflight_check() {
	if ! perf stat -e task-clock -- true > /dev/null 2>&1; then
		echo "error: unprivileged 'perf stat' is not working on this machine" >&2
		echo "(perf_event_paranoid=$(cat /proc/sys/kernel/perf_event_paranoid))." >&2
		echo "Run scripts/perf/setup_perf_perms.sh once (needs sudo), then retry." >&2
		exit 1
	fi
}

# run_perf <name> -- <command...>
# Wraps a command with `perf stat`, writing the raw counter report to
# raw/<name>.perf.log and the command's own stdout+stderr to raw/<name>.out.log.
run_perf() {
	local name=$1
	shift
	perf stat --no-big-num -e "$PERF_EVENTS" -o "$RAW_DIR/${name}.perf.log" -- \
		"$@" > "$RAW_DIR/${name}.out.log" 2>&1
}

# Appends every counter in raw/<name>.perf.log to $EVENTS_CSV.
record_perf_events() {
	local name=$1
	awk -v app="$name" -v cores="$CORES" -v threads="$CORES" '
		{ line = $0; sub(/^[ \t]+/, "", line); if (line == "") next }
		$1 == "<not" { printf "%s,%s,%s,%s,NA\n", app, cores, threads, $3; next }
		$1 ~ /^[0-9]+(\.[0-9]+)?$/ { printf "%s,%s,%s,%s,%s\n", app, cores, threads, $2, $1 }
	' "$RAW_DIR/${name}.perf.log" >> "$EVENTS_CSV"
}

record_metric() {
	local name=$1 metric=$2 value=$3
	printf '%s,%s,%s,%s,%s\n' "$name" "$CORES" "$CORES" "$metric" "$value" >> "$METRICS_CSV"
	printf '  %s: %s = %s\n' "$name" "$metric" "$value"
}

preflight_check
echo "Physical cores detected: $CORES (cpu range $CPU_RANGE, threads-per-core $THREADS_PER_CORE)"

for class in "${NAS_CLASSES[@]}"; do
	echo "-----NAS Class $class-----"
	for kernel in "${NAS_KERNELS[@]}"; do
		exe="$NAS_BIN_DIR/${kernel}.${class}.x"
		name="nas_${kernel}_${class}"
		echo "Running ${kernel^^} (Class $class) under perf..."

		run_perf "$name" env OMP_NUM_THREADS="$CORES" OMP_PROC_BIND=close OMP_PLACES=cores \
			taskset -c "$CPU_RANGE" "$exe"
		record_perf_events "$name"

		mops=$(awk -F'=' '/Mop\/s total/ { gsub(/ /,"",$2); print $2 }' "$RAW_DIR/${name}.out.log")
		runtime=$(awk -F'=' '/Time in seconds/ { gsub(/ /,"",$2); print $2 }' "$RAW_DIR/${name}.out.log")
		record_metric "$name" mops "$mops"
		record_metric "$name" runtime_s "$runtime"
	done
done

echo "-----CloverLeaf (bm32_short)-----"
(
	cd "$CLOVER_DIR"
	cp "$CLOVER_DECK" clover.in
	run_perf cloverleaf env OMP_NUM_THREADS="$CORES" OMP_PROC_BIND=close OMP_PLACES=cores \
		taskset -c "$CPU_RANGE" ./clover_leaf
	cp clover.out "$RAW_DIR/cloverleaf.app.out"
)
record_perf_events cloverleaf
vera=$(awk '/Wall clock/ { val = $3 } END { print val }' "$RAW_DIR/cloverleaf.app.out")
record_metric cloverleaf wall_clock_s "$vera"

echo "-----miniBUDE (bm1)-----"
run_perf minibude env OMP_NUM_THREADS="$CORES" OMP_PROC_BIND=close OMP_PLACES=cores \
	taskset -c "$CPU_RANGE" "$BUDE_EXE" -i 10 -p 256 --deck "$BUDE_DECK"
record_perf_events minibude
sum_ms=$(grep '^best:' "$RAW_DIR/minibude.out.log" | grep -oP 'sum_ms:\s*\K[0-9.]+')
record_metric minibude sum_ms "$sum_ms"

echo "-----Neutral (stream)-----"
(
	cd "$NEUTRAL_DIR"
	run_perf neutral env OMP_NUM_THREADS="$CORES" OMP_PROC_BIND=close OMP_PLACES=cores \
		taskset -c "$CPU_RANGE" ./neutral.omp3 "$NEUTRAL_DECK"
)
record_perf_events neutral
wallclock=$(grep -oP 'Final Wallclock \K[0-9.]+' "$RAW_DIR/neutral.out.log")
record_metric neutral wallclock_s "$wallclock"

echo "-----TeaLeaf (bm_5e_2)-----"
(
	cd "$TEALEAF_DIR"
	cp "$TEALEAF_DECK" tea.in
	run_perf tealeaf env OMP_NUM_THREADS="$CORES" OMP_PROC_BIND=close OMP_PLACES=cores \
		taskset -c "$CPU_RANGE" ./build/omp-tealeaf
	cp tea.out "$RAW_DIR/tealeaf.app.out"
)
record_perf_events tealeaf
wallclock=$(grep -oP 'Wallclock:\s*\K[0-9.]+' "$RAW_DIR/tealeaf.app.out" | tail -1)
record_metric tealeaf wallclock_s "$wallclock"

echo "-----STREAM (gcc15)-----"
(
	cd "$STREAM_DIR"
	run_perf stream_gcc15 env OMP_NUM_THREADS="$CORES" OMP_PROC_BIND=spread OMP_PLACES=cores \
		taskset -c "$CPU_RANGE" ./stream_c.exe
)
record_perf_events stream_gcc15
awk '
	/^Copy:/ { copy = $2 }
	/^Scale:/ { scale = $2 }
	/^Add:/ { add = $2 }
	/^Triad:/ { triad = $2 }
	END {
		printf "stream_gcc15,copy_mb_s,%s\n", copy
		printf "stream_gcc15,scale_mb_s,%s\n", scale
		printf "stream_gcc15,add_mb_s,%s\n", add
		printf "stream_gcc15,triad_mb_s,%s\n", triad
	}
' "$RAW_DIR/stream_gcc15.out.log" | while IFS=, read -r name metric value; do
	record_metric "$name" "$metric" "$value"
done

printf 'Done.\nPer-event counters: %s\nApp metrics:        %s\nRaw logs:            %s\n' \
	"$EVENTS_CSV" "$METRICS_CSV" "$RAW_DIR"

