#!/bin/bash

B_DIR=$HOME/joseph/NPB3.4.4/NPB3.4-OMP/bin

echo "-----Running BT-----"
OMP_NUM_THREADS=88 OMP_PROC_BIND=close taskset -c 0-87 $B_DIR/bt.D.x

echo "-----Running CG-----"
OMP_NUM_THREADS=88 OMP_PROC_BIND=close taskset -c 0-87 $B_DIR/cg.D.x

echo "-----Running EP-----"
OMP_NUM_THREADS=88 OMP_PROC_BIND=close taskset -c 0-87 $B_DIR/ep.D.x

echo "-----Running LU-----"
OMP_NUM_THREADS=88 OMP_PROC_BIND=close taskset -c 0-87 $B_DIR/lu.D.x

echo "-----Running MG-----"
OMP_NUM_THREADS=88 OMP_PROC_BIND=close taskset -c 0-87 $B_DIR/mg.D.x

echo "-----Running SP-----"
OMP_NUM_THREADS=88 OMP_PROC_BIND=close taskset -c 0-87 $B_DIR/sp.D.x

echo "-----Running UA-----"
OMP_NUM_THREADS=88 OMP_PROC_BIND=close taskset -c 0-87 $B_DIR/ua.D.x

echo "-----Running FT-----"
OMP_NUM_THREADS=88 OMP_PROC_BIND=close taskset -c 0-87 $B_DIR/ft.D.x

echo "-----Running IS-----"
OMP_NUM_THREADS=88 OMP_PROC_BIND=close taskset -c 0-87 $B_DIR/is.D.x