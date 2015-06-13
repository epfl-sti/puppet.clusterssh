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
use autodie;

# Attempt to save stderr somewhere - No biggie if that fails
eval {
  open(STDERR, "> /var/log/puppet/gen-known_hosts.log")
    unless $ENV{TERM};
};

sub logmsg {
  my $now = localtime(time);
  carp "[$now] $_[0]";
}

logmsg "Running " . join(" ", @ARGV);

if (! defined $ENV{HOME}) {
  $ENV{HOME} = "/root";
}

chomp(my $puppetmaster_fqdn = `facter fqdn`);

my $key_source = HammerSource->open(qw(ssh key));

# Redirect only now, so that the file doesn't get created in case of failure
our ($outputfile, $outputfile_unique);
GetOptions("o=s" => sub {
  (undef, $outputfile) = @_;
  $outputfile_unique = "${outputfile}.$$";
  logmsg "Redirecting to $outputfile_unique";
  open(STDOUT, ">", $outputfile_unique);  # autodie
});

END {
  unlink($outputfile_unique) if ($? && $outputfile_unique);
}

while(my ($fqdn, $keytype, $pubkey) = $key_source->next) {
  next unless (my ($keytype_short) = ($keytype =~ m/ssh(\w+)key/));
  my $host = Host->find($fqdn);
  $host->add_key($keytype_short, $pubkey);
  my ($short_hostname) = ($fqdn =~ m|^(.*?)\.|);
  $host->add_name($short_hostname);
}

# Don't trust the bare "ipaddress" fact, as Docker messes it up!
# Always read all IPs, find out which ones look legit
my $ipaddress_source = HammerSource->open("ipaddress_");
while(my ($fqdn, $factname, $addr) = $ipaddress_source->next) {
  my ($ifname) = $factname =~ m/^ipaddress_(.*)$/;
  next unless $ifname;
  next if $ifname eq "lo";
  next if $addr =~ m/^172\.1[67]/;
  next if $addr =~ m/^127/;
  next if $addr =~ m/^169\.254/;
  Host->find($fqdn)->add_name($addr);
}

foreach my $host (Host->all) {
  my $aliases = join(",", $host->all_names);
  foreach my $keystruct ($host->all_keys) {
    my ($keytype_short, $pubkey) = @$keystruct;
    print "$aliases $keytype_short $pubkey\n";  # autodie
  }
}

close(STDOUT); # autodie, also next line
rename($outputfile_unique, $outputfile) if $outputfile;
exit 0;

package Host;

use vars qw(%all_hosts);

sub find {
  my ($class, $fqdn) = @_;
  $all_hosts{$fqdn} ||= bless {
    fqdn => $fqdn, keys => {}, aliases => []
  }, $class;
}

sub add_name {
  my ($self, $name) = @_;
  push @{$self->{aliases}}, $name;
}

sub all_names {
  my ($self) = @_;
  my %names_set = map {$_ => 1} ($self->{fqdn}, @{$self->{aliases}});
  # Sort letters before numbers:
  return reverse sort keys %names_set;
}

sub add_key {
  my ($self, $keytype, $key) = @_;
  $self->{keys}->{$keytype} = $key;
}

sub all_keys {
  my ($self) = @_;
  return map { [$_ => $self->{keys}->{$_}] }
    (sort keys %{$self->{keys}});
}

sub all {
  my ($class) = @_;
  return map { $all_hosts{$_} } (sort keys %all_hosts);
}

package HammerSource;

use IO::File;

sub open {
  my ($class, @searched) = @_;
  my $u_can_touch_this = new IO::File(sprintf(
    'unset LANG LC_ALL LC_LANGUAGE; $(which hammer) --output csv fact list %s --per-page 10000 |',
    join(" ", map {" --search '$_'"} @searched)));
  die "Stop! No hammertime: $!" if ! $u_can_touch_this;
  bless { _mc => $u_can_touch_this }, $class;
}

sub next {
  my ($self) = @_;
  for(1) {
    local $_ = $self->{_mc}->getline;
    return if ! defined;
    chomp;
    redo if m/,Fact,/;  # Header line
    my @bits = split m/,/;
    return @bits;
  }
}
