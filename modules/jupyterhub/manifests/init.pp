# == Class: jupyterhub
# Sets up a JupyterHub for WMF that spawns users with Systemd.
#
# Runs from a virtualenv created from analytics/jupyterhub/deploy
# repository, and also creates a virtualenv for each user as they log in.
#
# === Parameters
#
# [*port*]
#   JupyterHub port
#
# [*web_proxy*]
#   Set this to put http/https_proxy environment variables in the spawned
#   single user servers.
#
# [*posix_groups*]
#   Default: wikidev
#
# [*ldap_groups*]
#   If given,  'ldap' will be used as authenticator.  Else 'dummy'.
#   'dummy' uses DummyAuthenticator, which lets in anyone with any username
#   and password, as long as they already have a user account setup on the
#   machine. On labs, this means anyone with labs account.
#   'ldap' uses LDAPAuthenticator, configured to let only people with LDAP
#   credentials in. Currently restricted to members of the ops group only.
#   Default: undef
#
# [*systemd_slice*]
#   If given, 'systemd_slice' will force systemd spawner to use a certain
#   Systemd slice to run the notebook's units under. This is good when
#   some general resource constraints need to be made. By default the
#   units will run under the system slice, in which all the daemons are
#   usually running. This means that a heavy notebook server can affect
#   daemons running on the same host.
#   Default: user.slice
#
class jupyterhub (
    $port                  = 8000,
    $web_proxy             = undef,
    $ldap_groups           = undef,
    $ldap_server           = undef,
    $ldap_bind_dn_template = undef,
    $posix_groups          = ['wikidev'],
    $systemd_slice         = 'user.slice',
)
{
    require_package(
        'virtualenv',
        'python3-venv',
        'python3-wheel',
        # Packages for PDF exports
        'pandoc',
        'texlive-xetex',
        'texlive-fonts-recommended',
        'texlive-generic-recommended',
        # For pyhive and impyla
        'libsasl2-dev',
        'libsasl2-modules-gssapi-mit',
    )

    # jupyterhub can be included on profiles/roles that
    # already offer a nodejs configuration, like the stat100x hosts.
    # nodejs is needed for the embedded configurable-http-proxy.
    if !defined(Package['nodejs']) {
        # nodejs6 is EOL
        if os_version('debian == stretch') {
            if !defined(Apt::Package_from_component['wikimedia-node10']){
                apt::package_from_component { 'wikimedia-node10':
                    component => 'component/node10',
                    packages  => ['nodejs'],
                }
            }
        } else {
            # For embedded configurable-http-proxy
            require_package('nodejs')
        }
    }

    $deploy_repository = 'analytics/jupyterhub/deploy'
    $config_path       = '/etc/jupyterhub'
    $base_path         = '/srv/jupyterhub'
    $deploy_path       = "${base_path}/deploy"
    $wheels_path       = "${deploy_path}/artifacts/${::lsbdistcodename}/wheels"
    $venv_path         = "${base_path}/venv"
    $data_path         = '/var/lib/jupyterhub'
    $database_uri      = "sqlite:///${data_path}/jupyterhub.sqlite.db"

    file { [$base_path, $data_path, $config_path]:
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0775',
    }

    git::clone { $deploy_repository:
        ensure    => 'present',
        directory => $deploy_path,
        owner     => 'root',
        group     => 'root',
        mode      => '0775',
        require   => File[$base_path],
    }

    exec { 'jupyterhub_create_virtualenv':
        command => "${deploy_path}/create_virtualenv.sh ${venv_path}",
        creates => "${venv_path}/bin/jupyterhub",
        require => Git::Clone[$deploy_repository],
    }

    if os_version('debian >= buster') {
        $http_proxy_pid_file = '/tmp/jupyterhub-proxy.pid'
    } else {
        $http_proxy_pid_file = undef
    }

    file { "${config_path}/jupyterhub_config.py":
        ensure  => 'present',
        content => template('jupyterhub/jupyterhub_config.py.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Git::Clone[$deploy_repository],
    }

    # Generate a cookie secret.
    exec { 'jupyterhub_generate_cookie_secret':
        command     => "/usr/bin/openssl rand -hex 32 > ${config_path}/jupyterhub_cookie_secret",
        creates     => "${config_path}/jupyterhub_cookie_secret",
        environment => "RANDFILE=${config_path}/.rnd",
        umask       => '0377',
        user        => 'root',
        group       => 'root',
        require     => [Git::Clone[$deploy_repository], File['/etc/jupyterhub']],
    }

    systemd::syslog { 'jupyterhub':
        readable_by => 'group',
        base_dir    => '/var/log',
        owner       => 'root',
        group       => 'root',
        require     => Git::Clone[$deploy_repository],
    }

    systemd::service { 'jupyterhub':
        content   => systemd_template('jupyterhub'),
        restart   => true,
        subscribe => [
            File["${config_path}/jupyterhub_config.py"],
            Exec['jupyterhub_generate_cookie_secret']
        ],
        require   => [
            Git::Clone[$deploy_repository],
            Exec['jupyterhub_create_virtualenv'],
            Systemd::Syslog['jupyterhub'],
        ]
    }
}
