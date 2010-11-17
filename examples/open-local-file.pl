#!perl -w
use strict;
use WWW::Mechanize::Firefox;

my $mech = WWW::Mechanize::Firefox->new();
$mech->get_local('datei.html');

<>;