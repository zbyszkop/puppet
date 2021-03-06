class alertmanager::irc (
    Stdlib::Host $listen_host = 'localhost',
    Stdlib::Port $listen_port = 19190,
    Stdlib::Host $irc_host = 'localhost',
    Stdlib::Port $irc_port = 6697,
    String $irc_nickname = $title,
    String $irc_realname = $title,
    Optional[String] $irc_nickname_password = undef,
    Stdlib::Ensure::Service $service_ensure = running,
) {
    require_package('alertmanager-irc-relay')

    service { 'alertmanager-irc-relay':
        ensure => $service_ensure,
    }

    file { '/etc/alertmanager-irc-relay.yml':
        ensure    => present,
        owner     => 'alertmanager-irc-relay',
        group     => root,
        mode      => '0440',
        show_diff => false,
        content   => template('alertmanager/irc.yml.erb'),
        notify    => Service['alertmanager-irc-relay'],
    }
}
