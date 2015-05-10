#!/usr/bin/perl -w

use strict;

=head1 NAME

gen-known_hosts.pl - Create the ssh known_hosts file from fact data in Foreman

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

do {
  open(U_CAN_TOUCH_THIS,
     "hammer --output csv fact list --search sshrsakey  --per-page 1000 |");
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
sub fatal_cannot_write {
  if ($outputfile) {
    die "Cannot write to $outputfile: $!";
    unlink($outputfile);
  } else {
    die "Cannot write to standard output: $!";
  }
}

while(<U_CAN_TOUCH_THIS>) {
  chomp;
  my ($fqdn, undef, $pubkey) = split m/,/;
  print "$fqdn ssh-rsa $pubkey\n" or fatal_cannot_write;
}

close(STDOUT) or fatal_cannot_write;
exit 0;
