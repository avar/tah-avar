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
# Count how many tiles we skipped, if any
my $skip = 0;

while (<STDIN>) {
    # Skip comments
    if (/^#/) {
        $skip += 1;
        next;
    }

    chomp;
    my ($x, $y) = split /[, ]/, $_;
    push @tile, [ $x, $y ];
}

if ($skip) {
    print STDERR "Skipping $skip tiles\n";
}

for (my $i = 0; $i < @tile; $i++) {
    my ($x, $y) = @{ $tile[$i] };

    my $cmd = "$^X tilesGen.pl @ARGV xy $x $y $zoom";
    my $tried = 0;
    my $tries = 100;
    my $sleep = 15;
    my $step  = 60;
    my $ret;
  again:
    printf STDERR "Generating tile %d/%d ($x,$y)\n", ($i + 1 + $skip), (scalar(@tile) + $skip);
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

    system "$^X tilesGen.pl upload";
}
