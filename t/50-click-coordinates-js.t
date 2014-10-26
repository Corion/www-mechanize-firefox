#!perl

use warnings;
use strict;
use Test::More;

use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 1,
    #log => [qw[debug]],
    #on_event => 1,
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 3;
};

$mech->get_local("50-click-coordinates-js.html");

my $clicky_image = $mech->selector('#maplink', single => 1 );
my $pos= $clicky_image->getBoundingClientRect();
isa_ok( $clicky_image, 'MozRepl::RemoteObject::Instance', 'Found the image' );

my $resp = $mech->click({ dom => $clicky_image, synchronize => 0 }, 10, 12 );

my( $type,$co );
($co,$type)= $mech->eval_in_page('cX');
is( $co - $pos->{left}, 10, 'X co-ordinates got transmitted OK' );
($co,$type)= $mech->eval_in_page('cY');
is( $co - $pos->{top}, 12, 'Y co-ordinates got transmitted OK' );
