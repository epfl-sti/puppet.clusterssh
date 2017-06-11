# Class: clusterssh::private::ssh
#
# Configure and enable OpenSSH.
#
# Actions:
#
# * Ensure sshd is running
#
# * Configure IgnoreRhosts, EnableSSHKeysign, HostbasedAuthentication
#
# See also:
#
# http://serverfault.com/a/391467/109290
class clusterssh::private::ssh(
  $enable_root_shosts_equiv = false
) {
  case $::osfamily {
    "RedHat": {
      $sshd_service = "sshd"
    }
    default: {
      $sshd_service = "ssh"
    }
  }
  ensure_resource("service", $sshd_service, { ensure => 'running'})

  # https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Host-based_Authentication
  clusterssh::private::ssh::set_sshd_config { "HostbasedAuthentication":
    notify => Service[$sshd_service]
  }
  clusterssh::private::ssh::set_ssh_config {
    ["HostbasedAuthentication", "EnableSSHKeysign"]:
  }
  if ($enable_root_shosts_equiv) {
    # http://brandonhutchinson.com/wiki/Ssh_HostbasedAuthentication#HostbasedAuthentication_with_the_root_user
    clusterssh::private::ssh::set_sshd_config { "IgnoreRhosts":
      value => "no",
      notify => Service[$sshd_service]
    }
  }

  define set_ssh_config($value = "yes") {
    ssh_config { "clusterssh client ${name}":
      ensure => present,
      key    => $name,
      value  => $value,
    }
  }

  define set_sshd_config($value = "yes") {
    sshd_config { "clusterssh server ${name}":
      ensure => present,
      key    => $name,
      value  => $value,
    }
  }
}
