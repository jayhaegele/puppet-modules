$certname = $trusted['certname']

Package { allow_virtual => false }

hiera_include('classes')

realize Host["${::fqdn}"]

$packages_remove = hiera_array('packages::remove')
package { $packages_remove:
    ensure => 'absent',
}

ensure_packages(hiera_array('packages::install'))

create_resources(
    'firewall',
    hiera_hash('iptables::rules'),
    {
        require => [
            Class['firewall'],
            Package['firewalld'],
        ],
    }
)

resources { "firewall":
    purge => hiera('purge_iptables', true),
}

file_line { 'puppet-agent':
    path    => '/etc/puppet/puppet.conf',
    line    => '[agent]',
    match   => '^[agent]',
} ->
file_line { 'puppet-agent-server':
    path    => '/etc/puppet/puppet.conf',
    line    => "    server = ${servername}",
    match   => '^\s+server',
    after   => '^[agent]',
} ->
file_line { 'puppet-agent-interval':
    path    => '/etc/puppet/puppet.conf',
    line    => '    interval = 3600',
    match   => '^\s+interval',
    after   => '^[agent]',
    notify  => Service['puppet'],
}

file_line { 'network-nozeroconf':
    path    => '/etc/sysconfig/network',
    line    => 'NOZEROCONF=yes',
    match   => '^NOZEROCONF',
}

$services_enable = hiera_array('services::enable')
service { $services_enable:
    enable  => true,
}

$services_disable = hiera_array('services::disable')
service { $services_disable:
    enable  => false,
    ensure  => 'stopped',
}

$selinux_booleans_enable = hiera_array('selinux::booleans::enable', [])
selboolean { $selinux_booleans_enable:
    value       => 'on',
    persistent  => true,
}

$selinux_booleans_disable = hiera_array('selinux::booleans::disable', [])
selboolean { $selinux_booleans_disable:
    value       => 'off',
    persistent  => true,
}

create_resources(
    'sysctl',
    hiera_hash('sysctl::options'),
    { ensure => 'present', apply => true }
)

if !hiera('uefi', false) {
    create_resources(
        'kernel_parameter',
        hiera_hash('kernel::parameters'),
        { ensure => 'present' },
    )
}

create_resources(
    'ssh_authorized_key',
    hiera_hash('ssh::authorized_keys'),
    { ensure => 'present' },
)

user { 'root':
    password        => hiera('root_password'),
    home            => '/root',
    managehome      => true,
    purge_ssh_keys  => true,
}

create_resources(
    'mount',
    hiera_hash('mounts', {}),
    { ensure => 'present', atboot => true, },
)

create_resources(
    'group',
    hiera_hash('groups', {}),
    { ensure => 'present' },
)

create_resources(
    'user',
    hiera_hash('users', {}),
    { ensure => 'present' },
)

create_resources(
    'file',
    hiera_hash('files', {}),
)

###

create_resources(
    'apache::vhost',
    hiera_hash('apache::vhosts', {}),
)

create_resources(
    'htpasswd',
    hiera_hash('apache::users', {}),
    { target => '/etc/httpd/conf/htpasswd' },
)

$apache_mods = hiera_array('apache::mods', [])
::apache::mod { $apache_mods: }

###

file_line { 'yum-disable-deltarpm':
    path    => '/etc/yum.conf',
    line    => 'deltarpm=0',
    match   => '^#?deltarpm=',
    after   => '[main]',
}

cron { 'yum-update':
    command => 'sleep $((RANDOM / 600)) && /usr/bin/yum -q -y upgrade',
    user    => 'root',
    hour    => ['8', '17'],
    minute  => '0',
}

###
