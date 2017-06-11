class clusterssh::private::install_pdsh {
  ensure_resource("package", "pdsh", { ensure => 'installed'})
  if ($::osfamily == "RedHat") {
    if (1 == versioncmp("6.6", $::operatingsystemrelease)) {
      # RedHat 6.5 lacks pdsh -g support :(
      ensure_resource("package", "pdsh-mod-netgroup", { ensure => 'installed'})
    }
  }
}
