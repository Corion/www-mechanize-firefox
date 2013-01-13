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
    plan tests => 4;
};

$mech->get_local("52-iframeset.html");
$mech->click({selector => "#change_frame"});

my @frames = $mech->selector('#iframe');
is @frames, 1, "We found the one specified iframe";
like $frames[0]->{src}, qr/\b50-form2.html$/, "We found the right subframe";

$mech->get_local("52-iframeset.html");
$mech->click({selector => "#change_frame_404"});

@frames = $mech->selector('#iframe');
is @frames, 1, "We found the one specified iframe";
like $frames[0]->{src}, qr/\bdoes-not-exist.html$/, "That frame target was not found";
