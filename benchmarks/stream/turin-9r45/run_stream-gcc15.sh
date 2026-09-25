#!/usr/bin/env bash
set -euo pipefail

#module purge
#module load gcc/15

SOURCE_PATH=$HOME/joseph/STREAM
RESULTS_DIR=$HOME/turin-results/stream

cd "$SOURCE_PATH"


OMP_NUM_THREADS=96 OMP_PROC_BIND=spread OMP_PLACES=cores numactl --membind=0 taskset -c 0-95 ./stream_c.exe > $RESULTS_DIR/stream-full-cores.txt

