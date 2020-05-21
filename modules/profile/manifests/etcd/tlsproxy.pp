class profile::etcd::tlsproxy(
    Stdlib::Fqdn $cert_name = lookup('profile::etcd::tlsproxy::cert_name'),
    Hash[Stdlib::Unixpath, Array[String]] $acls = lookup('profile::etcd::tlsproxy::acls'),
    String $salt = lookup('profile::etcd::tlsproxy::salt'),
    Boolean $read_only = lookup('profile::etcd::tlsproxy::read_only'),
    Stdlib::Port $listen_port = lookup('profile::etcd::tlsproxy::listen_port'),
    Stdlib::Port $upstream_port = lookup('profile::etcd::tlsproxy::upstream_port'),
    Boolean $tls_upstream = lookup('profile::etcd::tlsproxy::tls_upstream')
) {
    require ::profile::tlsproxy::instance
    require ::passwords::etcd

    # this is a hash of user => password
    $accounts = $::passwords::etcd::accounts

    # TODO: also support TLS cert auth to the backend
    $upstream_scheme = $tls_upstream ? {
        true    => 'https',
        default => 'http'
    }

    $upstream_host = $tls_upstream ? {
        true    => $::fqdn,
        default => '127.0.0.1'
    }
    sslcert::certificate { $cert_name:
        skip_private => false,
        before       => Service['nginx'],
    }

    file { '/etc/nginx/auth/':
        ensure  => directory,
        mode    => '0550',
        owner   => 'www-data',
        require => Package['nginx-full'],
        before  => Service['nginx']
    }

    file { '/etc/nginx/etcd-errors':
        ensure  => directory,
        mode    => '0550',
        owner   => 'www-data',
        require => Package['nginx-full'],
        before  => Service['nginx']
    }

    # Simulate the etcd auth error
    file { '/etc/nginx/etcd-errors/401.json':
        ensure  => present,
        mode    => '0444',
        content => '{"errorCode":110,"message":"The request requires user authentication","cause":"Insufficient credentials","index":0}',
    }

    file { '/etc/nginx/etcd-errors/readonly.json':
        ensure  => present,
        mode    => '0444',
        content => '{"errorCode":107,"message":"This cluster is in read-only mode","cause":"Cluster configured to be read-only","index":0}',
    }

    $acls.each |$path, $users| {
        $file_location = regsubst($path, '/', '_', 'G')
        $file_name = "/etc/nginx/auth/${file_location}.htpasswd"

        file { $file_name:
            content => template('profile/etcd/htpasswd.erb'),
            owner   => 'www-data',
            group   => 'www-data',
            mode    => '0444',
        }
    }

    nginx::site { 'etcd_tls_proxy':
        ensure  => present,
        content => template('profile/etcd/tls_proxy.conf.erb'),
    }
}
