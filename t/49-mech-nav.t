#!perl

use warnings;
use strict;
use Test::More;

use WWW::Mechanize::Firefox;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

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

my $server = Test::HTTP::LocalServer->spawn(
    #debug => 1,
);

$mech->get($server->url);

$mech->click_button(number => 1);
like( $mech->uri, qr/formsubmit/, 'Clicking on button by number' );
my $last = $mech->uri;

diag "Going back";
$mech->back;
is $mech->uri, $server->url, 'We went back';

diag "Going forward";
$mech->forward;
is $mech->uri, $last, 'We went forward';
