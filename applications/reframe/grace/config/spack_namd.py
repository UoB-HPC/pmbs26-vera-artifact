import os
import reframe as rfm
import reframe.utility as util
import reframe.utility.sanity as sn
import reframe.utility.osext as osext
from spack_base import SpackCompileOnlyBase

class NamdSpackBuild(SpackCompileOnlyBase):
    sourcefile = os.path.join(os.getenv('HOME'),'work/sources/NAMD_3.0.1_Source.tar.gz')
    defspec = 'namd@3.0.1'
    defdeps = parameter(['^charmpp backend=multicore build-target=charm++'])

    # Segmentation fault for some reason in AWS AMD/Intel nodes.
    #@run_after('setup')
    #def setup_avxtiles(self):
    #    if "avx512" in self.current_partition.features:
    #        self.defspec = 'namd@3.0.1 +avxtiles'

# RegressionTest is used so Spack uses existing environment.
# This also uses same spec.
@rfm.simple_test
class NamdSpackCheck(rfm.RegressionTest):
    
    namd_binary = fixture(NamdSpackBuild, scope='environment')
    fullspackspec = variable(str)

    descr = 'NAMD test using Spack'
    build_system = 'Spack'
    valid_systems = ['*']

    valid_prog_environs = ['-no-namd']
    
    build_only = variable(int, value=0)
    num_nodes = parameter([1])
    num_threads = parameter([1])
    # Following not used but to keep option in if this changes.
    num_percent = variable(int, value=0)
    
    # NAMD can setcpuaffinity.- alternatively Slurm can with exclusive access.
    exclusive_access = True
    extra_resources = {
        'memory': {'size': '0'},
        'bind': {'bind': 'local'},
        'distribution': {'socket':'block'},
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
        #('apoa1',),
        ('stmv',),
        #('stmv_nve_cuda',)
    ], fmt=lambda x: x[0], loggable=True)

    executable = f"namd3"

    @run_after('init')
    def prepare_test(self):
        self.__bench, = self.benchmark_info
        self.descr = f'NAMD {self.__bench} benchmark'
        if self.__bench == 'stmv_nve_cuda':
            self.prerun_cmds = [
                f'curl -kLJO https://www.ks.uiuc.edu/Research/namd/utilities/stmv.tar.gz',
                f'curl -kLJO http://www.ks.uiuc.edu/Research/namd/2.13/benchmarks/stmv_nve_cuda.namd'
            ]
        else:
            self.prerun_cmds = [
                f'curl -kLJO https://www.ks.uiuc.edu/Research/namd/utilities/{self.__bench}.tar.gz',
            ]
        self.prerun_cmds.extend([
            f'curl -kLJO https://www.ks.uiuc.edu/Research/namd/utilities/ns_per_day.py',
            f'chmod +x ns_per_day.py',
            f'tar zxvf *.tar.gz --strip-components 1',
            f'sed -i \'s|/usr/tmp/||\' *.namd',
            f'export SLURM_HINT=nomultithread',
            f'ulimit -s unlimited',
            f'ulimit -c unlimited',
            ])
        self.postrun_cmds = [
            f'cat output.txt',
            f'./ns_per_day.py output.txt'
        ]
    

    @run_after('setup')
    def set_environment(self):
        self.skip_if(
            self.num_nodes > self.current_partition.extras.get('max_nodes',128),
            'exceeded node limit'
        )
        self.skip_if(
            self.num_threads > 12,
            'large threads encounter issues.'
        )

        self.build_system.environment = os.path.join(self.namd_binary.stagedir, 'rfm_spack_env')
        self.build_system.specs       = self.namd_binary.build_system.specs
        self.fullspackspec            = ' '.join(self.namd_binary.build_system.specs)
    
    @run_before('run')
    def set_job_size(self):

        self.skip_if( self.build_only == 1, 'build only')
        #self.job.launcher.options = ['--cpu-bind=ldoms']
        proc = self.current_partition.processor
        #nppn = 4
        #n_cores = proc.num_cores
        #ppn = (n_cores-nppn)/nppn
        #compe = n_cores-1
        #fppn = ppn+1

        self.num_tasks_per_node = 1
        #if self.num_threads:
        #    self.num_tasks_per_node = 1
        #    self.num_cpus_per_task = proc.num_cores*self.num_threads
        #    self.env_vars['OMP_NUM_THREADS'] = self.num_threads
        #    self.env_vars['OMP_PLACES'] = 'threads'
        #    self.env_vars['OMP_PROC_BIND'] = 'true'
        self.num_tasks = self.num_tasks_per_node * self.num_nodes
        
        #if self.num_nodes == 1:
        #    self.extra_resources.update( {
        #        'network': {'type': 'single_node_vni'},
        #        }
        #    )
        #self.executable_opts += [f'+setcpuaffinity +p{proc.num_cores*self.num_threads}'
        #                         f' +pemap 0-{(proc.num_cores*self.num_threads)-1} {self.__bench}.namd > output.txt']
        self.executable_opts += [f'+p{proc.num_cores_per_socket*self.num_threads} +setcpuaffinity +maffinity +CmiSleepOnIdle +pemap 0-71 {self.__bench}.namd > output.txt']


        # Following is the more basic example
        #self.executable_opts += [f'+setcpuaffinity +ppn {self.num_threads-1} {self.__bench}.namd > output.txt']

    @loggable
    @property
    def bench_name(self):
        '''The benchmark name.

        :type: :class:`str`
        '''

        return self.__bench
    
    @run_before('sanity')
    def set_sanity_patterns(self):
        self.sanity_patterns = sn.assert_found(r'End of program', self.stdout)

    @run_before('performance')
    def set_perf_patterns(self):
        self.perf_patterns = {
            'Nanoseconds per day:':
            sn.extractsingle(r'Nanoseconds per day: +([0-9.]+)', self.stdout, 1, float)
        }

