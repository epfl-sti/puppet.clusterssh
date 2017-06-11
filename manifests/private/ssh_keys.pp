# Class: clusterssh::private::ssh_keys
#
# Exchange ssh keys among cluster members (in /etc/ssh/ssh_known_hosts)
#
# Uses Puppet's "exported facts" feature, which requires PuppetDB to be
# set up and functional.
#
# This does *not* grant any permissions, although it is a necessary first step
# for the RhostsRSAAuthentication scheme to work.
#
# Actions:
#
# * Ensure that all keys from all hosts that match one of the $key_types,
#   are copied onto each node's /etc/ssh/ssh_known_hosts.
#
# See also:
#
# http://serverfault.com/a/391467/109290

class clusterssh::private::ssh_keys(
  $key_types = [ "rsa", "dsa", "ecdsa-sha2-nistp256", "ed25519"]
) {
  # All known keys go to /etc/ssh/ssh_known_hosts:
  Sshkey <<| |>>

  # Export keys from this host:
  $key_types.each |$keytype| {
    $_key_unique_name = inline_template("sshkey-<%= @keytype %>-<%= @fqdn.gsub('.', '-') %>")
    $_key_fact_name = inline_template("ssh<%= @keytype.split('-')[0] %>key")
    $_key_value = inline_template("<%= scope['${_key_fact_name}'] %>")
    if ($_key_value and !empty($_key_value)) {
      # "@@" means that that resource is a so-called "exported" resource
      # (marked as such in puppetdb). To test, one can query resources
      # like so (from the puppetmaster):
      #
      #   curl -k -v --cert /var/lib/puppet/ssl/certs/$(hostname -f).pem  \
      #     --key /var/lib/puppet/ssl/private_keys/$(hostname -f).pem \
      #     https://$(hostname -f):8081/pdb/query/v4/resources/Sshkey
      #
      @@sshkey { $_key_unique_name:
        host_aliases => [$::hostname, $::fqdn, $::ipaddress],
        ensure => present,
        type => $keytype,
        key  => $_key_value
      }
    }
  }
}
