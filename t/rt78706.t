#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

$ENV{ MOZREPL_CLASS } = 'MozRepl'; # we want the Net::Telnet-based implementation

my $mech = eval { WWW::Mechanize::Firefox->new( 
    activate => 1,
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 3;
};
diag "Using ", ref $mech->repl->repl;

isa_ok $mech, 'WWW::Mechanize::Firefox';
my $response;
my $result = eval {
    $mech->autoclose_tab( 0 );
    1
};
ok $result, "We lived"
    or diag $@;

   $result = eval {
    $mech->autoclose_tab( 1 );
    1
};
ok $result, "We lived"
    or diag $@;

undef $mech;
# ... and our tab gets closed, hopefully