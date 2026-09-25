#!/bin/bash

B_DIR=$HOME/joseph/NPB3.4.4/NPB3.4-OMP/bin

echo "-----Running IS-----"
OMP_NUM_THREADS=96 OMP_PROC_BIND=close taskset -c 0-95 $B_DIR/is.D.x
