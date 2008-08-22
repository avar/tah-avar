#!/usr/bin/env perl
use strict;
use warnings;
use Math::Trig;
use Pod::Usage ();
use Getopt::Long ();
use XML::Parser ();

=head1 NAME

osm-to-tilenumbers - Reads coordinates from an F<.osm> file and output their aggregated tile numbers

=head1 SYNOPSIS

Get all tiles covering an area at zoom level 12:

    osm-to-tilenumbers < Area.osm

Use a custom zoom level:

    osm-to-tilenumbers --zoom 6 < Area.osm

Get every tile that has been modified in the last month:

    osm-to-tilenumbers --zoom 12 --predicate 'abs($sec_ago) < (60**2 * 24 * 30)' < Area.osm

=head1 DESCRIPTION

Reads all the coordinates from an OpenStreetMap F<.osm> file and
outputs newline seperated list of tiles that are guaranteed to cover
every all of those coordinates.

=head1 OPTIONS

=over

=item -z, --zoom

The zoom levels of the tiles, a higher zoom level will give you more

=item -p, --predicate

A code snippet that can be supplied to weed out unwanted coordinates
given some condition, it's passed to C<eval> and if the code returns
true we keep the value.

The following variables are guarenteed to be set:

    my ($timestamp, $lat, $lon) = @attr{qw(timestamp lat lon)};
    my ($x, $y)                 = getTileNumber($lat, $lon, $zoom);

    my $dt          = DateTime::Format::ISO8601->parse_datetime($timestamp);
    my $coord_epoch = $dt->epoch;
    my $epoch       = time();
    my $sec_ago     = $coord_epoch - $epoch;

For example, to get all tiles at zoom level 12 above the arctic cicle
that have been modified in the last two weeks:

    osm-to-tilenumbers --zoom 12 --predicate '$lat > 66 and abs($sec_ago) < (60**2 * 24 * 14)' < Area.osm

=back

=cut

Getopt::Long::Parser->new(
	config => [ qw< bundling no_ignore_case no_require_order pass_through > ],
)->getoptions(
	'h|help'   => \my $help,
    'z|zoom=i' => \(my $zoom = 12),
    'p|predicate=s'   => \my $predicate,
) or help();

my $xml = XML::Parser->new(
    Handlers => {
        Start => \&handle_start,
    },
);

our %tile;

if (not -t STDIN) {
    # Read from STDIN
    $xml->parse(*STDIN);
} elsif ($ARGV[0] and -f $ARGV[0]) {
    $xml->parsefile($ARGV[0]);
} else {
    help();
}

print $_, "\n" for sort keys %tile;

exit 0;

sub handle_start
{
    my ($parser, $element, %attr) = @_;

    # We only care about <node>
    return unless $element eq 'node'
                  and exists $attr{lat}
                  and exists $attr{lon}
                  and exists $attr{timestamp};

    my ($timestamp, $lat, $lon) = @attr{qw(timestamp lat lon)};
    my ($x, $y) = getTileNumber($lat, $lon, $zoom);

    if ($predicate) {
        require DateTime::Format::ISO8601;

        my $dt = DateTime::Format::ISO8601->parse_datetime($timestamp);
        my $coord_epoch  = $dt->epoch;
        my $epoch = time();
        my $sec_ago = $coord_epoch - $epoch;

        my $res = eval $predicate;
        return unless $res;
    }

    $tile{"$x,$y"} = undef;
}

# From the OSMwiki
sub getTileNumber {
  my ($lat,$lon,$z) = @_;
  my $xtile = int( ($lon+180)/360 *2**$z ) ;
  my $ytile = int( (1 - log(tan($lat*pi/180) + sec($lat*pi/180))/pi)/2 *2**$z ) ;
  return(($xtile, $ytile));
}

sub help
{
    my %arg = @_;

    Pod::Usage::pod2usage(
        -verbose => $arg{ verbose },
        -exitval => $arg{ exitval } || 0,
    );
}
