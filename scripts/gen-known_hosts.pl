#!/usr/bin/perl -w

use strict;

=head1 NAME

gen-known_hosts.pl - Create the ssh_known_hosts file from fact data in Foreman

=head1 SYNOPSIS

  gen-known_hosts.pl [ -o <outputfile> ]

=head1 DESCRIPTION

This script collects the C<sshrsakey> facts from Foreman (using the
C<hammer> CLI tool) and processes them into OpenSSH's C<known_hosts>
format.

=cut

use Getopt::Long;
use Carp qw(carp);

# Attempt to save stderr somewhere - No biggie if that fails
open(STDERR, "> /var/log/puppet/gen-known_hosts.log");

sub logmsg {
  my $now = localtime(time);
  carp "[$now] $_[0]";
}

logmsg "Running " . join(" ", @ARGV);

if (! defined $ENV{HOME}) {
  $ENV{HOME} = "/root";
}

chomp(my $puppetmaster_fqdn = `facter fqdn`);

do {
  open(U_CAN_TOUCH_THIS,
     "hammer --output csv fact list --search sshrsakey  --per-page 1000 |" .
       " sort |");
} or die "Stop! No hammertime: $!";

# Redirect only now, so that the file doesn't get created in case of failure
our ($outputfile, $outputfile_unique);
GetOptions("o=s" => sub {
  (undef, $outputfile) = @_;
  $outputfile_unique = "${outputfile}.$$";
  logmsg "Redirecting to $outputfile_unique";
  open(STDOUT, ">", $outputfile_unique) or
    die "Cannot open $outputfile_unique for writing: $!";
});

END {
  unlink($outputfile_unique) if ($? && $outputfile_unique);
}

while(<U_CAN_TOUCH_THIS>) {
  chomp;
  next if m/,Fact,/;  # Header line
  my ($fqdn, undef, $pubkey) = split m/,/;
  my ($hostname) = ($fqdn =~ m|^(.*?)\.|);
  my $cmd = "env - /usr/bin/host '$fqdn' |";
  open(HOST, $cmd) or die "Cannot run '$cmd': $!";
  my @aliases = ($fqdn, $hostname);
  while(<HOST>) {
    m/has address ([0-9.]+)/ && push(@aliases, $1);
    m/has IPv6 address ([0-9:]+)/ && push(@aliases, "[$1]");
  }
  close(HOST);
  $? && die "$cmd failed with code $?";

  # The Puppet master might have an alias on the internal network.
  # TODO: using hammer --search ipaddr, we could drop the assumption
  # that only the Puppet master can be multi-homed.
  if ($fqdn eq $puppetmaster_fqdn) {
    open(FACTER, "facter |") or die "facter doesn't deliver: $!";
    while(<FACTER>) {
      chomp;
      next unless (m/ipaddress.* => ((?:[0-9]+[.]){3}[0-9]+)/);
      my $maybe_internal_ip = $1;
      chomp(my $gethostbyaddr = `getent hosts $maybe_internal_ip`);
      unless ($gethostbyaddr =~ m/[0-9.]+\s+(\S+)/) {
        logmsg "Unable to getent hosts $maybe_internal_ip (result: $gethostbyaddr)";
        next;
      };
      my $another_fqdn = $1;
      next if $another_fqdn =~ m/localhost/;
      next if grep { $_ eq $another_fqdn } @aliases;
      push @aliases, $maybe_internal_ip, $another_fqdn;
      my ($another_hostname) = ($another_fqdn =~ m|^(.*?)\.|);
      push @aliases, $another_hostname;
    }
  }

  my $aliases = join(",", @aliases);
  print "$aliases ssh-rsa $pubkey\n" or die "Cannot write: $!";
}

close(STDOUT) or die "Cannot close: $!";
rename($outputfile_unique, $outputfile) or
  die "Cannot rename $outputfile_unique to $outputfile: $!";
exit 0;
