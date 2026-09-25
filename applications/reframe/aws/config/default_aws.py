site_configuration = {

    'general' : [
        {
            'remote_detect': True
        }
    ],
    'storage' : [
        {
            'enable': True
        }
    ],
    'logging' : [
        {
            'handlers_perflog' : [
				{
                    'type': 'filelog',
                    'prefix': '%(check_system)s/%(check_partition)s',
                    'level': 'info',
                    'format': ('%(check_result)s|'
                               '%(check_job_completion_time)s|%(check_#ALL)s'),
                    'ignore_keys': [
                        'check_build_locally',
                        'check_build_time_limit',
                        'check_display_name',
                        'check_executable',
                        'check_executable_opts',
                        'check_hashcode',
                        'check_keep_files',
                        'check_local',
                        'check_maintainers',
                        'check_max_pending_time',
                        'check_outputdir',
                        'check_prebuild_cmds',
                        'check_prefix',
                        'check_prerun_cmds',
                        'check_postbuild_cmds',
                        'check_postrun_cmds',
                        'check_readonly_files',
                        'check_sourcepath',
                        'check_sourcesdir',
                        'check_stagedir',
                        'check_strict_check',
                        'check_tags',
                        'check_time_limit',
                        'check_valid_prog_environs',
                        'check_valid_systems',
                        'check_variables'
                    ],
                    'format_perfvars': (
                        '%(check_perf_value)s|%(check_perf_unit)s|'
                        '%(check_perf_ref)s|%(check_perf_lower_thres)s|'
                        '%(check_perf_upper_thres)s|'
                    ),
                    'append': False
                }
            ]
        }
    ],
    'environments' : [
        {
            'name': 'gcc-15',
            'features': [
                'no-cray-mpich',
            ],
            'extras' : {
                'myrepos': 'buildit/repo/v1.1/spack_repo/isamrepo',
                'mypackage': 'buildit/config/aws/v1.1/packages.yaml',
                'myspackcomp': 'gcc@15.3.0'
            }
        },
    ],
    'systems': [
        {
            'name': 'aws',
            'descr': 'AWS Cluster',
            'hostnames': ['localhost'],
            'env_vars': [ 
                ['MYCONFDIR','$HOME/work/git']
            ],
            'partitions': [
                {
                    'name': 'local',
                    'descr': 'Localhost system',
                    'scheduler': 'local',
                    'launcher': 'local',
                    'max_jobs': 1,
                    'environs': ['gcc-15'],
                    'features': ['avx512']
                },
                {
                    'name': 'parallel',
                    'descr': 'Parallel localhost system',
                    'scheduler': 'local',
                    'launcher': 'mpirun',
                    'max_jobs': 1,
                    'environs': ['gcc-15'],
                    'features': ['avx512']
                },
                {
                    'name': 'lepyc',
                    'descr': 'Localhost system',
                    'scheduler': 'local',
                    'launcher': 'local',
                    'max_jobs': 1,
                    'environs': ['gcc-15'],
                    'features': ['avx512']
                },

                {
                    'name': 'epyc',
                    'descr': 'Parallel epyc system',
                    'scheduler': 'local',
                    'launcher': 'mpirun',
                    'max_jobs': 1,
                    'environs': ['gcc-15'],
                    'features': ['avx512']
                },

            ]
        },
    ]
}
