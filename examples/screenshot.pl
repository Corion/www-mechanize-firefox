#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Getopt::Long;
use Pod::Usage;

GetOptions(
    'mozrepl|m:s' => \my $mozrepl,
    'outfile|o:s' => \my $outfile,
    'tab|t:s' => \my $tab,
    'current|c' => \my $current,
) or pod2usage();
$outfile ||= 'screenshot.png';

my @args;
if (! @ARGV) {
    push @args, tab => 'current';
};

if ($tab) {
    $tab = qr/$tab/;
};

my $mech = WWW::Mechanize::Firefox->new(
    launch => 'firefox',
    create => 1,
    tab => $tab,
    autoclose => !($current || $tab),
    @args
);

if (@ARGV) {
    $mech->get($ARGV[0]);
};
my $png = $mech->content_as_png();

open my $out, '>', $outfile
    or die "Couldn't create '$outfile': $!";
binmode $out;
print {$out} $png;

=head1 NAME

screenshot.pl - take a screenshot of a webpage

=head1 SYNOPSIS

screenshot.pl [options] [url]

Options:
   --outfile        name of output file
   --mozrepl        connection string to Firefox

=head1 OPTIONS

=over 4

=item B<--outfile>

Name of the output file. The image will always be written
in PNG format.

=item B<--mozrepl>

Connection information for the mozrepl instance to use.

=back

=head1 DESCRIPTION

B<This program> will take a screenshot
of the given URL (including plugins) and
write it to the given file or the file C<screenshot.png>.

=cut