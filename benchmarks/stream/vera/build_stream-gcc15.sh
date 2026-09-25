#module purge
#module load gcc/15

SCRIPT_PATH=$HOME/joseph/scripts/stream
SOURCE_PATH=$HOME/joseph/STREAM

cp $SCRIPT_PATH/Makefile-gcc15 $SOURCE_PATH/Makefile
cd $SOURCE_PATH
make clean
make -j
