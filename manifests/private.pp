# This is a bunch of useful things destined to be 'include'd.
class clusterssh::private {
  # For namespacing only; this class performs no action.

  # Sync a file from <modulepath_of_clusterssh>/files/generated/ to any path.
  #
  # Usage example:
  # 
  #   clusterssh::private::sync_file_from_puppetmaster { "known_hosts":
  #      path => "/etc/ssh/known_hosts"
  #   }
  #
  define sync_file_from_puppetmaster(
    $filename = $name,
    $path = undef,
    $owner = "root",
    $group = "root",
    $mode = "644"
    ) {
    validate_string($path)
    $module_path = get_module_path("clusterssh")
    $puppet_path = "puppet:///modules/clusterssh/generated/${filename}"
    # Trick from https://ask.puppetlabs.com/question/5849/check-if-file-exists-on-client/
    if (inline_template("<% if File.exist?('${module_path}/files/generated/${filename}') -%>true<% end -%>")) {
      file { $path:
        owner => $owner,
        group => $group,
        mode => $mode,
        source => $puppet_path
      }
    } else {
      warning("${puppet_path} (still?) doesn't exist on Puppet master")
    }
  }

  define set_ssh_config($value = "yes") {
    ssh_config { "clusterssh ${name} global":
      ensure => present,
      key    => $name,
      value  => $value,
    }
  }

  define set_sshd_config($value = "yes") {
    sshd_config { "clusterssh ${name}":
      ensure => present,
      key    => $name,
      value  => $value,
    }
  }
}

class clusterssh::private::install_pdsh {
  if ($::operatingsystem == "RedHat") {
    ensure_resource("package", "pdsh", { ensure => 'installed'})
    if ($operatingsystemrelease == "6.6") {
      # pdsh has no netgroup support in RHEL 6.5 :-(
      # TODO: pdsh -g still works, but apparently uses the config from "dsh"
      # (https://rtcamp.com/tutorials/linux/dsh/).  We could support that too.
      ensure_resource("package", "pdsh-mod-netgroup", { ensure => 'installed'})
    }
  }
}
