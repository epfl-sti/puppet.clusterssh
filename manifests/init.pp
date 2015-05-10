# == Class: clusterssh
#
# Set up /etc/netgroup and SSH host-based authentication for pdsh bliss.
#
# === Parameters
#
# [*role*]
#   Either "agent", "puppetmaster", or "autodetect" (the latter, according
#   to whether Foreman's hammer tool is installed)
#
# === Actions:
# * Runs hammer (Foreman's CLI) on the Puppet master to enumerate known hosts
# * Creates known_hosts file inside this module's files/ directory
#
class clusterssh(
  $role = "autodetect",
) {
  validate_re($role, '^agent$|^puppetmaster$|^autodetect$')

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
    # Bag of ugly quirks to do the simplest thing, in spite of Puppet
    # trying to prevent it: create a config file from a script.
    #
    # * Put the output in the source tree of the module (under files/), it being the
    #   only place where it can be downloaded from on slave nodes
    # * trick exec() into not knowing that the script runs every time (otherwise
    #   the master node would never go green again in the Foreman dashboard)
    $module_path = get_module_path("clusterssh")
    exec { "/bin/false # clusterssh gen-known_hosts.pl":
      unless => "${module_path}/scripts/gen-known_hosts.pl -o ${module_path}/files/generated/known_hosts",
    }
  }
  $known_hosts_on_master = "puppet:///modules/clusterssh/generated/known_hosts"
  # Trick from https://ask.puppetlabs.com/question/5849/check-if-file-exists-on-client/
  if (inline_template("<% if File.exist?('${module_path}/files/generated/known_hosts') -%>true<% end -%>")) {
    file { "/etc/ssh/known_hosts":
      owner => "root",
      group => "root",
      mode => "644",
      source => $known_hosts_on_master
    }
  } else {
    warning("${known_hosts_on_master} (still?) doesn't exist")
  }
}
