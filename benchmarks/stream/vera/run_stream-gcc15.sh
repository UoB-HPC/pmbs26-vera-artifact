#!/usr/bin/env bash
set -euo pipefail

#module purge
#module load gcc/15

SOURCE_PATH=$HOME/joseph/STREAM
RESULTS_DIR=$HOME/joseph/results/stream

cd "$SOURCE_PATH"


OMP_NUM_THREADS=88 OMP_PROC_BIND=spread OMP_PLACES=cores taskset -c 0-87 ./stream_c.exe > $RESULTS_DIR/stream-full-cores.txt

