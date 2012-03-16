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
    plan tests => 22;
};

my $server = Test::HTTP::LocalServer->spawn();

$mech->get($server->url);

my @forms = $mech->forms;
my $form = $forms[0];

CLICK_BY_NUMBER: {
    $mech->click_button(number => 1);

    like( $mech->uri, qr/formsubmit/, 'Clicking on button by number' );
    like( $mech->uri, qr/submit=Go/,  'Correct button was pressed' );
    like( $mech->uri, qr/cat_foo/,    'Parameters got transmitted OK' );
    $mech->back;

    ok(! eval { $mech->click_button(number => 2); 1 }, 'Button number out of range');
}

CLICK_BY_NAME: {
    $mech->click_button(name => 'submit');
    like( $mech->uri, qr/formsubmit/, 'Clicking on button by name' );
    like( $mech->uri, qr/submit=Go/,  'Correct button was pressed' );
    like( $mech->uri, qr/cat_foo/,    'Parameters got transmitted OK' );
    $mech->back;

    ok(! eval { $mech->click_button(name => 'bogus'); 1 },
    'Button name unknown');
}

CLICK_BY_ID: {
    $mech->click_button(id => 'submit_button');
    like( $mech->uri, qr/formsubmit/, 'Clicking on button by name' );
    like( $mech->uri, qr/submit=Go/,  'Correct button was pressed' );
    like( $mech->uri, qr/cat_foo/,    'Parameters got transmitted OK' );
    $mech->back;

    ok(! eval { $mech->click_button(id => 'no_such_button'); 1 },
    'Button name unknown');
    ok(! eval { $mech->click_button(id => 'query'); 1 },
    'Button name unknown');
}

CLICK_BY_VALUE: {
    $mech->click_button(value => 'Go');
    like( $mech->uri, qr/formsubmit/, 'Clicking on button by value' );
    like( $mech->uri, qr/submit=Go/,  'Correct button was pressed' );
    like( $mech->uri, qr/cat_foo/,    'Parameters got transmitted OK' );
    $mech->back;

    ok(! eval { $mech->click_button(value => 'bogus'); 1 },
    'Button value unknown');
}

CLICK_BY_OBJECT_REFERENCE: {
    #local $TODO = q{It seems that calling ->click() on an object is broken in LWP. Need to investigate further.};

    #my $clicky_button = $form->find_input( undef, 'submit' );
    my $clicky_button = $mech->xpath('//*[@type="submit"]', single => 1 );
    isa_ok( $clicky_button, 'MozRepl::RemoteObject::Instance', 'Found the submit button' );
    is( $clicky_button->{value}, 'Go', 'Named the right thing, too' );

    my $resp = $mech->click_button(input => $clicky_button);
    {use Data::Dumper; local $Data::Dumper::Sortkeys=1;
        diag Dumper( $resp->request )}

    like( $mech->uri, qr/formsubmit/, 'Clicking on button by object reference' );
    like( $mech->uri, qr/submit=Go/,  'Correct button was pressed' );
    like( $mech->uri, qr/cat_foo/,    'Parameters got transmitted OK' );

    $mech->back;
}
