class clusterssh::private {
  # Sync a file from <modulepath_of_clusterssh>/files/generated/ to any path.
  #
  # Usage example:
  # 
  #   clusterssh::private::sync_file_from_puppetmaster { "known_hosts":
  #      path => "/etc/ssh/known_hosts"
  #   }
  #
  define sync_file_from_puppetmaster(
    $path = undef,
    $owner = "root",
    $group = "root",
    $mode = "644"
    ) {
    validate_string($path)
    $module_path = get_module_path("clusterssh")
    $puppet_path = "puppet:///modules/clusterssh/generated/${name}"
    # Trick from https://ask.puppetlabs.com/question/5849/check-if-file-exists-on-client/
    if (inline_template("<% if File.exist?('${module_path}/files/generated/${name}') -%>true<% end -%>")) {
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
}
