# clusterssh

#### Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
3. [Setup](#setup)
    * [What clusterssh affects](#what-clusterssh-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with clusterssh](#beginning-with-clusterssh)
4. [Usage](#usage)
5. [Limitations](#limitations)
6. [Development](#development)

## Overview

Make [pdsh](https://code.google.com/p/pdsh/) work on your cluster like so:

    pdsh -g mycluster-all date

[Foreman](http://theforeman.org/) is required - *This module doesn't work with vanilla Puppet*

*WARNING: ALPHA QUALITY!* A number of
steps that should be automated, still need to be done manually.
([We](http://sti.epfl.ch/it) are already using this module in one
production cluster and one development cluster, though - Your mileage
may vary.)

## Module Description

This module installs and configures
[`pdsh`](https://code.google.com/p/pdsh/) and
[ssh host-based authentication](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Host-based_Authentication)
in your cluster. It uses Foreman's
[stored Puppet facts](http://projects.theforeman.org/projects/foreman/wiki/Puppet_Facts)
feature as the ground truth for host names, IP addresses and public keys.

Only Red Hat (and CentOS) 6 and 7 are supported at this point.

The following tasks are performed:
* Manage `/etc/ssh/ssh_known_hosts`, `shosts.equiv`, `/root/.shosts` and `/etc/netgroup` files
* Optionally, install [`pdsh`](https://code.google.com/p/pdsh/)
* Manage the required configuration items in `ssh_config` and `sshd_config`, public key permissions etc.

## Setup

### What clusterssh affects

* Generate master copies of `ssh_known_hosts`, `shosts.equiv` and (*UNIMPLEMENTED*) `/etc/netgroup` on the Puppet master
  * For the time being, you still have to create the `netgroup` master by hand under `modules/clusterssh/files/generated/netgroup`
* Distribute these files on all nodes, also as `/root/.shosts` (required for password-less login for root)
* Set `netgroup: files` in `/etc/nsswitch.conf`, lest `/etc/netgroup` have no effect
* Straighten key permissions w.r.t. those of `ssh-keysign(8)` on the distribution (as its name implies, that tool needs to read the private keys)
* Optionally install [`pdsh`](https://code.google.com/p/pdsh/)

### Setup Requirements

[Foreman](http://theforeman.org/) is required - *This module doesn't work with vanilla Puppet*

### Beginning with clusterssh

    puppet module install epflsti/clusterssh


    class { 'clusterssh': }

## Usage

    class { 'clusterssh':
      role => $role,  # "agent", "master" or "autodetect"
      manage_nsswitch_netgroup => $boolean,
      manage_pdsh_packages => $boolean,
      enable_root_shosts_equiv => $boolean
    }

See
[the documentation header in `init.pp`](https://github.com/epfl-sti/puppet.clusterssh/blob/master/manifests/init.pp)
for details.

## Limitations

[Foreman](http://theforeman.org/) is required - *This module doesn't work with vanilla Puppet*

Only Red Hat (and CentOS) 6 and 7 are supported at this point.

## Development

Please fork
[the GitHub project](https://github.com/epfl-sti/puppet.clusterssh/)
and create a pull request on GitHub.

