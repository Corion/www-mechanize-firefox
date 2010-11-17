#!perl -w
use strict;
use WWW::Mechanize::Firefox;

my $mech = WWW::Mechanize::Firefox->new(
    activate => 1, # bring the tab to the foreground
);
$mech->get('http://www.perlworkshop.de');

<>;