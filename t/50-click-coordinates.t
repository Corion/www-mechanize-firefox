#!perl

use warnings;
use strict;
use Test::More;

use WWW::Mechanize::Firefox;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

plan skip_all => "ISMAP seems unsupported from Javascript. Need to investigate further.";

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
    plan tests => 2;
};

my $server = Test::HTTP::LocalServer->spawn();

$mech->get($server->url);

SKIP: {
    my $clicky_image = $mech->selector('#ismap', single => 1 );
    isa_ok( $clicky_image, 'MozRepl::RemoteObject::Instance', 'Found the image' );

    my $resp = $mech->click({ dom => $clicky_image }, 10, 12 );

    like( $mech->uri, qr/\?10,12/,      'Co-ordinates got transmitted OK' );

}


