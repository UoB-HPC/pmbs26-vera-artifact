# Applications (Fig. 11)

Six scientific applications, built with Spack and run with ReFrame on one
socket of each platform. The results are in
`results/applications/app-comparison.csv`; `gnuplot/make_apps_csv.py` turns
them into `data/applications/apps.csv`.

| app | Spack spec | case | input | figure of merit |
|---|---|---|---|---|
| CASTEP | `castep@25.1.1` | al3x3 | `al3x3.tgz` | run time (s) |
| CP2K | `cp2k@2024.3+mpi` | fayalite (`Fayalite-FIST`) | `benchmarks/Fayalite-FIST/fayalite.inp` from the CP2K GitHub repo | run time (s) |
| GROMACS | `gromacs@2025.3` (`~sve` on Vera) | TestCaseB | PRACE UEABS 2.2 `GROMACS_TestCaseB.tar.xz`; `-nsteps 50000` | ns/day |
| NAMD | `namd@3.0.1 ^charmpp backend=multicore` | stmv | `stmv.tar.gz` from ks.uiuc.edu | ns/day |
| OpenFOAM | `openfoam@2312 ^cgal@5` | HPC_motorbike (Large, v1912) | OpenFOAM HPC committee repo; `endTime 100` | run time (s) |
| WRF | `wrf@4.6.1 build_type=dm+sm ^hdf5+fortran` | CONUS 12 km | `v4.4_bench_conus12km.tar.gz` (UCAR) | mean time step (s) |

The exact download commands and case edits are in the `prerun_cmds` of each
`applications/reframe/<system>/config/spack_<app>.py`.

## Software

- Spack `releases/v1.1` (https://github.com/spack/spack), with
  `patches/spack_archspec.patch`. The patch adds an `olympus` (Vera) entry to
  archspec, derived from `neoverse_v2`, so that Spack passes
  `-mcpu=olympus` to GCC 15.
- Spack package repository and `packages.yaml`: isambard-sc/buildit, tag
  `v2.1` (https://github.com/isambard-sc/buildit), files
  `repo/v1.1/spack_repo/isamrepo` and `config/<system>/v1.1/packages.yaml`.
- ReFrame 4.9.3 (https://reframe-hpc.readthedocs.io).
- Compiler: GCC 15.3.0 (`gcc@15.3.0`). MPI: `mpich@4.3.0` (set in
  `spack_base.py` for the `no-cray-mpich` environment).
- CASTEP is closed source (free academic licence, https://www.castep.org).
  Put `CASTEP-25.11.tar.gz` in `~/sources/`; it is not included here.
  NAMD needs `NAMD_3.0.1_Source.tar.gz` in `~/sources/` (free registration).

## Set up

```bash
git clone --depth=2 --branch=releases/v1.1 https://github.com/spack/spack.git
(cd spack && patch -p1 < <artifact>/applications/patches/spack_archspec.patch)
. spack/share/spack/setup-env.sh

mkdir -p $MYCONFDIR && cd $MYCONFDIR        # MYCONFDIR is set in the system config file
git clone https://github.com/isambard-sc/buildit.git
(cd buildit && git checkout v2.1)

python3 -m venv venv && . venv/bin/activate
pip install -U pip && pip install "reframe-hpc==4.9.3"
cp -r <artifact>/applications/reframe/<system>/config .
```

## Run

| system | config file (`-C`) | non-MPI `--system` | MPI `--system` |
|---|---|---|---|
| AWS EPYC 9R45 | `aws/config/default_aws.py` | `aws:lepyc` | `aws:epyc` |
| AWS Xeon 6975P-C | `aws/config/default_aws.py` | `aws:local` | `aws:parallel` |
| Vera | `vera/config/default_nvidia.py` | `nvidia:local` | `nvidia:parallel` |
| Grace | `grace/config/default_grace.py` | `grace:local` | `grace:parallel` |

Example for Grace (NAMD uses the non-MPI partition, the others the MPI one):

```bash
reframe -C config/default_grace.py -c config/spack_castep.py   --system=grace:parallel -S valid_prog_environs=gcc-15 -r
reframe -C config/default_grace.py -c config/spack_cp2k.py     --system=grace:parallel -S valid_prog_environs=gcc-15 -r
reframe -C config/default_grace.py -c config/spack_gromacs.py  --system=grace:parallel -S valid_prog_environs=gcc-15 -r
reframe -C config/default_grace.py -c config/spack_namd.py     --system=grace:local    -S valid_prog_environs=gcc-15 -r
reframe -C config/default_grace.py -c config/spack_openfoam.py --system=grace:parallel -S valid_prog_environs=gcc-15 -r
reframe -C config/default_grace.py -c config/spack_wrf.py      --system=grace:parallel -S valid_prog_environs=gcc-15 -r
```

Each test first builds the application in a Spack environment, then runs
it. The figure of merit is printed by ReFrame and written to its perflog;
wall time was taken from the job output where the test does not report it.

## Placement

- MPI codes: one rank per core, `mpirun --bind-to core --map-by numa`.
  SMT runs (`num_threads=2`) keep one rank per core and add
  `OMP_NUM_THREADS=2`, `OMP_PLACES=threads`, `OMP_PROC_BIND=true`.
- NAMD: one multicore process, `+p<cores x threads> +setcpuaffinity
  +maffinity +CmiSleepOnIdle` (Grace adds `+pemap 0-71`).
- OpenFOAM: pure MPI, no SMT runs; `numberOfSubdomains` = number of ranks.
- WRF: SMT runs also set `OMP_STACKSIZE=64M`.
- Grace configs run SMT-off only (Grace has one thread per core).