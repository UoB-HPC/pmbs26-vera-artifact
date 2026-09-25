import os
import re
import reframe as rfm
import reframe.utility as util
import reframe.utility.sanity as sn
from spack_base import SpackCompileOnlyBase


@sn.deferrable
def extract_timings(rsl_error_path):
    step_times = []
    with open(rsl_error_path) as f:
        for line in f:
            match = re.search(r'Timing for main: time \S+ on domain\s+\d+:\s+([\d.]+) elapsed seconds', line)
            if match is not None:
                step_times.append(float(match.group(1)))
    return step_times

TIMING_CONSTANTS = {
    'v4.4_bench_conus12km': {
        'model_timestep': 72,
        'gflops_factor': 0.418,
    },
    '2.5km': {
        'model_timestep': 15,
        'gflops_factor': 27.45,
    }
}


class WrfSpackBuild(SpackCompileOnlyBase):
    defspec = 'wrf@4.6.1 build_type=dm+sm'
    defdeps = parameter(['^hdf5 +fortran'])



# RegressionTest is used so Spack uses existing environment.
# This also uses same spec.
@rfm.simple_test
class WrfSpackCheck(rfm.RegressionTest):

    wrf_binary = fixture(WrfSpackBuild, scope='environment')
    fullspackspec  = variable(str)
 
    descr = 'Wrf test using Spack'
    build_system = 'Spack'
    valid_systems = ['*']

    valid_prog_environs = ['-no-wrf']

    build_only = variable(int, value=0)
    num_nodes = parameter([1])
    num_threads = parameter([1,2])
    exclusive_access = True
    extra_resources = {
        'memory': {'size': '0'},
    }

    #: The version of the benchmark suite to use.
    #:
    #: :type: :class:`str`
    #: :default: ``'1.0.0'``
    benchmark_version = variable(str, value='1.0.0', loggable=True)

    #: Parameter pack encoding the benchmark information.
    #:
    #: The first element of the tuple refers to the benchmark name,
    #: the second is the energy reference and the third is the
    #: tolerance threshold.
    #:
    #: :type: `Tuple[str, float, float]`
    #: :values:
    benchmark_info = parameter([
        #('HECBioSim/Crambin', -204107.0, 0.001)
        #('HECBioSim/Glutamine-Binding-Protein', -724598.0, 0.001),
        #('HECBioSim/hEGFRDimer', -3.32892e+06, 0.001),
        #('HECBioSim/hEGFRDimerSmallerPL', -3.27080e+06, 0.001),
        #('HECBioSim/hEGFRDimerPair', -1.20733e+07, 0.001),
        #('HECBioSim/hEGFRtetramerPair', -2.09831e+07, 0.001)
        ('v4.4_bench_conus12km'),
    ], fmt=lambda x: x[0], loggable=True)

    executable = '${WRF_HOME}/main/wrf.exe'
    keep_files = ['wrf/rundir/rsl.error.0000','wrf/rundir/rsl.out.0000','run.out']


    @run_after('init')
    def prepare_test(self):
        self.__bench = self.benchmark_info
        self.descr = f'WRF {self.__bench} benchmark'
        self.prerun_cmds.append([
            'WORK_DIR=${PWD}/wrf; WRF_INP=${WORK_DIR}/input; WRF_RUN=${WORK_DIR}/rundir',
            'mkdir -p ${WORK_DIR} ${WRF_INP} ${WRF_RUN}',
            'cd ${WRF_INP}',
            '# From: https://www2.mmm.ucar.edu/wrf/users/benchmark/v44/v4.4_bench_conus12km.tar.gz',
            f'tar xvf ${{HOME}}/sources/{self.__bench}.tar.gz -C ${{WRF_INP}} --strip-components 1',
            'cd ${WRF_RUN}',
            'ln -sfn ${WRF_HOME}/run/* .',
            'cp ${WRF_HOME}/configure.wrf .',
            'rm -rf namelist.input rsl.* wrfout* 1node1tile',
            'ln -sfn ${WRF_INP}/* .',
        ])

    @run_after('setup')
    def set_environment(self):
        self.skip_if(
            self.num_nodes > self.current_partition.extras.get('max_nodes',128),
            'exceeded node limit'
        )
        self.build_system.environment = os.path.join(self.wrf_binary.stagedir, 'rfm_spack_env')
        self.build_system.specs       = self.wrf_binary.build_system.specs
        self.fullspackspec            = ' '.join(self.wrf_binary.build_system.specs)

    @run_before('run')
    def set_job_size(self):
        self.skip_if( self.build_only == 1, 'build only')

        self.job.launcher.options = ['--bind-to core', '--map-by numa']
        proc = self.current_partition.processor
        self.num_tasks_per_node = proc.num_cores
        if self.num_threads:
            self.num_tasks_per_node = (proc.num_cores)
            self.env_vars['OMP_NUM_THREADS'] = self.num_threads
            self.env_vars['OMP_STACKSIZE'] = "64M"
            self.env_vars['OMP_PROC_BIND'] = "TRUE"
            self.env_vars['OMP_PLACES'] = "threads"
        self.env_vars['WRFIO_NCD_NO_LARGE_FILE_SUPPORT'] = "1"

        self.num_tasks = self.num_tasks_per_node * self.num_nodes
    
    @loggable
    @property
    def bench_name(self):
        '''The benchmark name.

        :type: :class:`str`
        '''

        return self.__bench

    #@performance_function('ns/day')
    #def perf(self):
    #    return sn.extractsingle(r'Performance:\s+(?P<perf>\S+)',
    #                            'md.log', 'perf', float)
    @run_before('sanity')
    def set_sanity_patterns(self):
        self.sanity_patterns = sn.all([
            sn.assert_found(r'wrf: SUCCESS COMPLETE WRF', 'wrf/rundir/rsl.error.0000'),
        ])

    @run_before('performance')
    def set_perf_patterns(self):
        model_timestep = TIMING_CONSTANTS[self.bench_name]['model_timestep']
        gflops_factor = TIMING_CONSTANTS[self.bench_name]['gflops_factor']
        self.perf_patterns = {
            'gflops': (model_timestep / sn.avg(extract_timings('wrf/rundir/rsl.error.0000'))) * gflops_factor,
            'avg_ts': sn.avg(extract_timings('wrf/rundir/rsl.error.0000'))
        }
