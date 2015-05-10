#!/usr/bin/perl -w

use strict;

=head1 NAME

gen-known_hosts.pl - Create the ssh_known_hosts file from fact data in Foreman

=head1 SYNOPSIS

  gen-known_hosts.pl [ -o <outputfile> ]

=head1 DESCRIPTION

This script collects the C<sshrsakey> facts from Foreman (using the
C<hammer> CLI tool) and processes them into OpenSSh's C<known_hosts>
format.

=cut

use Getopt::Long;

# Attempt to save stderr somewhere - No biggie if that fails
open(STDERR, "> /var/log/puppet/gen-known_hosts.log");

my $now = localtime(time);
warn "[$now] Running $0 " . join(" ", @ARGV);

if (! defined $ENV{HOME}) {
  $ENV{HOME} = "/root";
}

chomp(my $puppetmaster_fqdn = `facter fqdn`);

do {
  open(U_CAN_TOUCH_THIS,
     "hammer --output csv fact list --search sshrsakey  --per-page 1000 |" .
       " sort |");
  defined(<U_CAN_TOUCH_THIS>);  # Skip header
} or die "Stop! No hammertime: $!";

# Redirect only now, so that the file doesn't get created in case of failure
our $outputfile;
GetOptions("o=s" => sub {
  (undef, $outputfile) = @_;
  warn "Redirecting to $outputfile";
  open(STDOUT, ">", $outputfile) or
    die "Cannot open $outputfile for writing: $!";
});

END {
  unlink($outputfile) if ($? &&$outputfile);
}

while(<U_CAN_TOUCH_THIS>) {
  chomp;
  my ($fqdn, undef, $pubkey) = split m/,/;
  my ($hostname) = ($fqdn =~ m|^(.*?)\.|);
  open(HOST, "env - /usr/bin/host '$fqdn' |") or die "Cannot run host: $!";
  my @aliases = ($fqdn, $hostname);
  while(<HOST>) {
    m/has address ([0-9.]+)/ && push(@aliases, $1);
    m/has IPv6 address ([0-9:]+)/ && push(@aliases, "[$1]");
  }

  # The Puppet master might have an alias on the internal network.
  if ($fqdn eq $puppetmaster_fqdn) {
    open(FACTER, "facter |") or die "facter doesn't deliver: $!";
    while(<FACTER>) {
      chomp;
      next unless (m/ipaddress.* => ([0-9.]+)/);
      my $maybe_internal_ip = $1;
      chomp(my $gethostbyaddr = `getent hosts $maybe_internal_ip`);
      next unless ($gethostbyaddr =~ m/[0-9.]+ (\S+)/);
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
exit 0;
