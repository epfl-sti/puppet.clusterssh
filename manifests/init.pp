# == Class: clusterssh
#
# Set up /etc/netgroup and SSH host-based authentication for pdsh bliss.
#
# === Parameters
#
# [*role*]
#   Either "agent", "puppetmaster", or "autodetect" (the latter, according
#   to whether Foreman's hammer tool is installed)
# [*manage_nsswitch_netgroup*] 
#   Whether to manage the netgroup entry in nsswitch.conf.
#   Set to false to let e.g. domq/epfl_sso set this entry.
# [*manage_pdsh_packages*] 
#   Whether to manage the installation of pdsh and pdsh-mod-netgroup.
#   Set this to false if you manage this packages by yourself, or if
#   you don't want to install pdsh.
#
# === Actions:
# * Runs hammer (Foreman's CLI) on the Puppet master to enumerate known hosts
# * Creates known_hosts file inside this module's files/ directory
#
class clusterssh(
  $role = "autodetect",
  $manage_nsswitch_netgroup = true,
  $manage_pdsh_packages = true,
) {
  validate_re($role, '^agent$|^puppetmaster$|^autodetect$')
  validate_bool($manage_nsswitch_netgroup)
  validate_bool($manage_pdsh_packages)

  if ($role == "autodetect") {
    if ($::has_hammer) {
      $resolved_role = "puppetmaster"
    } else {
      $resolved_role = "agent"
    }
  } else {
    $resolved_role = $role
  }

  if ($resolved_role == "puppetmaster") {
    # Bag of ugly tricks to do the simplest thing, despite the efforts
    # of Puppet to prevent it: create a config file from a script.
    #
    # * Put the output in the source tree of the module (under files/), it being the
    #   only place where it can be downloaded from on slave nodes
    # * trick exec() into not knowing that the script runs every time (otherwise
    #   the master node would never go green again in the Foreman dashboard)
    #
    $module_path = get_module_path("clusterssh")
    exec { "/bin/false # clusterssh gen-known_hosts.pl":
      unless => "${module_path}/scripts/gen-known_hosts.pl -o ${module_path}/files/generated/known_hosts",
    }
  }

  include('clusterssh::private')
  clusterssh::private::sync_file_from_puppetmaster { "known_hosts":
    path => "/etc/ssh/known_hosts"
  }
  clusterssh::private::sync_file_from_puppetmaster { "netgroup":
    path => "/etc/netgroup"
  }

  if ($manage_nsswitch_netgroup) {
    name_service { 'netgroup':
      # Who needs a real Yellow Pages service when we have Puppet?
      lookup => ['files']
    }
  }

  if ($manage_pdsh_packages) {
    ensure_resource("package", ["pdsh", "pdsh-mod-netgroup"],
                    { ensure => 'installed'})
  }  
}
