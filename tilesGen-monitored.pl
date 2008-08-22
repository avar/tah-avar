#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long ();

=pod

Given a newline delimited list of coordinates this runs tilesGen.pl monitored

=cut

Getopt::Long::Parser->new(
	config => [ qw< bundling no_ignore_case no_require_order pass_through > ],
)->getoptions(
	'h|help'   => \my $help,
    'z|zoom=i' => \(my $zoom = 12),
) or help();

my @tile;
my $skip = shift;

while (<>) {
    chomp;
    my ($x, $y) = split /[, ]/, $_;
    push @tile, [ $x, $y ];
}

for (my $i = 0; $i < @tile; $i++) {
    if (defined $skip and $i < $skip) {
        warn "Skipping up to $skip, this is $i";
        next;
    }

    my ($x, $y) = @{ $tile[$i] };

    my $cmd = "perl tilesGen.pl xy $x $y $zoom";
    my $tried = 0;
    my $tries = 100;
    my $sleep = 15;
    my $step  = 60;
    my $ret;
  again:
    printf STDERR "Generating tile %d/%d ($x,$y)\n", $i, scalar @tile;
    $ret = system $cmd;
    if ($ret) {
        warn "$cmd attempt $tried/$tries (num: $i) failed, sleeping $sleep and trying again";
        if ($tried < $tries) {
            $tried++;
            sleep $sleep;
            $sleep += $step;
            goto again;
        } else {
            die  "Tried $cmd $tries times, giving up";
        }
    }

    system "perl tilesGen.pl upload";
}
