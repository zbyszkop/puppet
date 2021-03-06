# = Class: statistics::performance
class statistics::performance (
    $use_kerberos = false,
) {
    Class['::statistics'] -> Class['::statistics::performance']

    $working_path = $::statistics::working_path

    $user = 'analytics-privatedata'
    $group = 'analytics-privatedata-users'

    scap::target { 'performance/asoranking':
        deploy_user => 'analytics-deploy',
        key_name    => 'analytics_deploy',
        manage_user => true,
    }

    kerberos::systemd_timer { 'performance-asoranking':
        description       => 'ASO ranking report monthly run',
        command           => '/usr/bin/python3 /srv/deployment/performance/asoranking/asoranking.py --debug --threshold 1000 --publish',
        # Run at noon on the first day of every month
        interval          => '*-*-01 12:00:00',
        user              => $user,
        logfile_name      => 'asoranking.log',
        logfile_owner     => $user,
        logfile_group     => $group,
        syslog_force_stop => true,
        syslog_identifier => 'performance-asoranking',
        use_kerberos      => $use_kerberos,
        slice             => 'user.slice',
        require           => Scap::Target['performance/asoranking'],
    }
}
