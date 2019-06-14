# cirrus checks
define icinga::monitor::elasticsearch::cirrus_checks(
    Enum['http', 'https'] $scheme = 'http',
    String $host = $::hostname,
    Array[Stdlib::Port] $ports = [9200],
) {
    $ports.each |$port| {
        monitoring::service { "elasticsearch / cirrus frozen writes - ${host}:${port}":
            host          => $host,
            check_command => "check_cirrus_frozen_writes!${scheme}!${port}",
            description   => "ElasticSearch health check for frozen writes - ${port}",
            critical      => true,
            contact_group => 'admins,team-discovery',
            notes_url     => 'https://wikitech.wikimedia.org/wiki/Search#Pausing_Indexing',
        }

        monitoring::service { "elasticsearch / masters eligible - ${host}:${port}":
            host          => $host,
            check_command => "check_masters_eligible!${scheme}!${port}",
            description   => "ElasticSearch numbers of masters eligible - ${port}",
            critical      => false,
            contact_group => 'admins,team-discovery',
            notes_url     => 'https://wikitech.wikimedia.org/wiki/Search#Expected_eligible_masters_check_and_alert',
        }
    }
}
