#!/bin/bash

module purge
module load gcc/15

cd $HOME/joseph/miniBUDE/openmp
make COMPILER=GNU ARCH=graniterapids WGSIZE=256