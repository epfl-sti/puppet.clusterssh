#!/usr/bin/perl -w

use strict;

=head1 NAME

gen-shosts_equiv.pl - Create the shosts.equiv file from an ssh_known_hosts file

=head1 SYNOPSIS

  gen-shosts_equiv.pl [ -i <ssh_known_hosts path> ] [ -o <outputfile> ]

=head1 DESCRIPTION

This script collects all the host names from an C<ssh_known_hosts>
file and collates them into OpenSSH's C<shosts.equiv> format.

=cut

use Getopt::Long;
use Carp qw(carp);

# Attempt to save stderr somewhere - No biggie if that fails
open(STDERR, "> /var/log/puppet/gen-shosts_equiv.log");

sub logmsg {
  my $now = localtime(time);
  carp "[$now] $_[0]";
}

logmsg "Running " . join(" ", @ARGV);

if (! defined $ENV{HOME}) {
  $ENV{HOME} = "/root";
}

# Redirect only now, so that the file doesn't get created in case of failure
our ($inputfile, $outputfile);
GetOptions(
  "i=s" => \$inputfile,
  "o=s" => sub {
  (undef, $outputfile) = @_;
  logmsg "Redirecting to $outputfile";
  open(STDOUT, ">", $outputfile) or
    die "Cannot open $outputfile for writing: $!";
});

END {
  unlink($outputfile) if ($? && $outputfile);
}

die "-i flag is required" unless $inputfile;

open(INPUT, "<", $inputfile);
while(<INPUT>) {
  chomp;
  my ($hostnames) = split m/\s+/;
  foreach (split m/,/, $hostnames) {
    print "$_\n" or die "Cannot write: $!";
  }
}

close(STDOUT) or die "Cannot close: $!";
exit 0;
