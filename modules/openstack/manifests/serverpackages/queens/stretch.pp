class openstack::serverpackages::queens::stretch(
){
    $stretch_bpo_packages = [
      'librados2',
      'librgw2',
      'librbd1',
      'python-rados',
      'python-rbd',
      'ceph-common',
      'python-cephfs',
      'libradosstriper1',
    ]

    apt::pin { 'openstack-queens-stretch-bpo':
        package  => join($stretch_bpo_packages, ' '),
        pin      => 'release n=stretch-backports',
        priority => '1002',
    }

    apt::repository { 'openstack-queens-stretch':
        uri        => 'http://mirrors.wikimedia.org/osbpo',
        dist       => 'stretch-queens-backports',
        components => 'main',
        source     => false,
        keyfile    => 'puppet:///modules/openstack/serverpackages/osbpo-pubkey.gpg',
        notify     => Exec['openstack-queens-stretch-apt-upgrade'],
    }

    apt::repository { 'openstack-queens-stretch-nochange':
        uri        => 'http://mirrors.wikimedia.org/osbpo',
        dist       => 'stretch-queens-backports-nochange',
        components => 'main',
        source     => false,
        keyfile    => 'puppet:///modules/openstack/serverpackages/osbpo-pubkey.gpg',
        notify     => Exec['openstack-queens-stretch-apt-upgrade'],
    }

    # ensure apt can see the repo before any further Package[] declaration
    # so this proper repo/pinning configuration applies in the same puppet
    # agent run
    exec { 'openstack-queens-stretch-apt-upgrade':
        command     => '/usr/bin/apt-get update',
        require     => [Apt::Repository['openstack-queens-stretch'],
                        Apt::Repository['openstack-queens-stretch-nochange']],
        subscribe   => [Apt::Repository['openstack-queens-stretch'],
                        Apt::Repository['openstack-queens-stretch-nochange']],
        refreshonly => true,
        logoutput   => true,
    }
    Exec['openstack-queens-stretch-apt-upgrade'] -> Package <| |>
}
