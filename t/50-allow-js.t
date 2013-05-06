#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 7;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';
$mech->autodie(1);

# Why doesn't this disallow JS when NoScript is installed?
$mech->allow('javascript' => 0);
$mech->get_local('50-click.html');
$mech->allow('javascript' => 0);

my ($clicked,$type,$end);
eval {
    ($clicked, $type) = $mech->eval_in_page('clicked');
    $end = 1;
};
if (! $end) {
    is $end, undef, "We didn't run to the end of the block";
    like $@, qr/clicked is not defined/, "JS is disallowed" or diag $clicked;
    SKIP: { 
        skip "We won't even see the timer", 1
    };
} else {
    SKIP: { 
        skip "Noscript is installed", 2
    };
    
    # Now, check that the timer does not fire:
    sleep 2;
    eval {
        ($clicked, $type) = $mech->eval_in_page('counter');
        $end = 1;
    };
    is $clicked, 0, "Timer didn't fire";
};

$end = undef;
$mech->allow('javascript' => 1);
$mech->get_local('50-click.html');
eval {
    ($clicked, $type) = $mech->eval_in_page('clicked');
    $end = 1;
};
ok $end, "No exception"
    or diag $@;
ok $clicked, "We found 'clicked'";

sleep 2;
eval {
    ($clicked, $type) = $mech->eval_in_page('counter');
    $end = 1;
};
is $clicked, 1, "Timer did fire";
