#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan skip_all => "Frames aren't testing well currently";
    exit;
    plan tests => 3;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->allow('metaredirects', 0); # protect ourselves against redirects
#$mech->allow('frames', 0); # protect ourselves against redirects

my $fn = 't/52-mech-api-find_link.html';
open my $fh, '<', $fn
    or die "Couldn't read '$fn': $!";
my $content = do { local $/; <$fh> };
$mech->update_html($content);
ok( $mech->success, "Fetched $fn" ) or die q{Can't get test page};

my $x;
$x = $mech->find_all_links(tag => 'iframe');
is 0+@$x, 3, "We found three FRAME tags";

my @frames = $mech->selector('frame');
is 0+@frames, 3, "We found three FRAME tags via ->selector";

@frames = $mech->xpath('//frame');
is 0+@frames, 3, "We found three FRAME tags via ->xpath";
