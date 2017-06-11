# == Class: clusterssh
#
# Set up /etc/netgroup and SSH host-based authentication for pdsh bliss.
#
# === Parameters:
#
# [*manage_nsswitch_netgroup*] 
#   Whether to manage the netgroup entry in nsswitch.conf.
#   Set to false to let e.g. domq/epfl_sso set this entry.
#
# [*install_pdsh*]
#   Whether to manage the installation of pdsh and pdsh-mod-netgroup.
#   Set this to false if you manage this packages by yourself, or if
#   you don't want to install pdsh.
#
# [*enable_root_shosts_equiv*] 
#   Boolean, whether to make clusterssh::shosts_equiv also work for root.
#
# === Actions:
#
# * Ensure sshd is running and configured for host-based authentication,
#   so that all accounts are equivalent (in the /etc/shosts.equiv sense)
#
# * (Optionally) Install pdsh
#
# * Do *NOT* change shosts.equiv or /etc/netgroup. For that, you have
#   to invoke a define explicitly.
#
# === Defines:
#
# ==== clusterssh::netgroup
#
# Define a netgroup in /etc/netgroup (for pdsh -g).
#
# For example, putting
# the following in your code makes "pdsh -g my-compute-nodes" work:
# (thanks to the puppetdb_query function that comes with puppetdb;
# see https://docs.puppet.com/puppetdb/latest/api/query/tutorial.html)
#
# clusterssh::netgroup { "my-compute-nodes":
#   hosts = puppetdb_query(["from", "nodes", ["~", "certname", "compute"]])
# }
#
# `hosts` can be either a list of host names, or a list of things that have
# a `.certname` (like the result of a `puppetdb_query` in ["from", "nodes"]
# or ["from", "facts"] - Duplicates are permitted and eliminated)
#
# ==== clusterssh::shosts_equiv
#
# Make these hosts part of /etc/ssh/shosts.equiv. This defined type can
# only be called once.
#
# For example, putting
# the following in your code makes "pdsh -g my-compute-nodes" work:
# (thanks to the puppetdb_query function that comes with puppetdb;
# see https://docs.puppet.com/puppetdb/latest/api/query/tutorial.html)
#
# clusterssh::shosts_equiv { "all":  # Name doesn't matter
#   hosts => puppetdb_query(["from", "nodes"])
# }
#
# `hosts` can be either a list of host names, or a list of things that have
# a `.certname` (like the result of a `puppetdb_query` in ["from", "nodes"]
# or ["from", "facts"] - Duplicates are permitted and eliminated)

class clusterssh(
  $manage_nsswitch_netgroup = true,
  $install_pdsh = true,
  $enable_root_shosts_equiv = true
) {
  validate_bool($manage_nsswitch_netgroup)
  validate_bool($install_pdsh)

  if ($manage_nsswitch_netgroup) {
    name_service { 'netgroup':
      # Who needs a real Yellow Pages service when we have Puppet?
      lookup => ['files']
    }
  }

  class { "clusterssh::private::ssh": }
  class { "clusterssh::private::ssh_keys": }
  if ($install_pdsh) {
    class { "clusterssh::private::install_pdsh": }
  }


  define netgroup($hosts) {
    exec { "touch /etc/netgroup # for ${title}":
      path => $::path,
      creates => "/etc/netgroup"
    } ->
    file_line { "${title} in /etc/netgroup":
      path => '/etc/netgroup',
      match => "^${title} ",
      line => inline_template('<%=@title %><% @hosts.map { |h| h["certname"] rescue h }.sort.uniq.each do |host | %> (<%= host %>,,)<% end %>')
    }
  }
  define shosts_equiv($hosts) {
    file { '/etc/ssh/shosts.equiv':
      content => inline_template('<% @hosts.map { |h| h["certname"] rescue h }.sort.uniq.each do |host| -%>
<%= host %>
<% end %>')
    }
  }
}
