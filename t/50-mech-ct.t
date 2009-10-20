#!perl -w
use strict;
use Test::More tests => 2;
use WWW::Mechanize::FireFox;

my $mech = WWW::Mechanize::FireFox->new( autodie => 0 );
isa_ok $mech, 'WWW::Mechanize::FireFox';

#my ($site,$estatus) = ('http://doesnotexit.example',500);
#\my ($site,$estatus) = ('http://corion.net/test',200);
#my $status = $mech->get($site);

is $mech->ct, 'text/html', "Content-type";

