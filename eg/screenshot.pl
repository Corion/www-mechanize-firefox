#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Getopt::Long;
use Pod::Usage;

GetOptions(
    'mozrepl|m:s' => \my $mozrepl,
    'outfile|o:s' => \my $outfile,
) or pod2usage();
$outfile ||= 'screenshot.png';

my @args;
if (! @ARGV) {
    push @args, tab => 'current';
};

my $mech = WWW::Mechanize::Firefox->new(
    launch => 'firefox',
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