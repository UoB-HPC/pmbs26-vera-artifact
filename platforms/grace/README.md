# Grace (Isambard 3)

One socket (72 Neoverse V2 cores) of a Grace-Grace Superchip node of the
Isambard 3 system. All runs are bound to socket 0 with
`numactl --cpunodebind=0 --membind=0` and submitted through Slurm.

Compiler: GCC 15.3.0 built in the user's home directory
(`$HOME/tools/gcc-15.3.0`), arch flag `-mcpu=neoverse-v2`.

TODO(grace-sysinfo): add `lscpu.txt`, `numactl.txt` (`numactl -H`) and
`gcc-version.txt` (`gcc -v`) from an Isambard 3 compute node.
