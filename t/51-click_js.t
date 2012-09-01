#!perl
use warnings;
use strict;
use Test::More;

use WWW::Mechanize::Firefox;
use lib 'inc', '../inc';

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
    plan tests => 4;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->get_local('51-click_js.html');

my ($triggered,$type,$ok);
eval {
    ($triggered, $type) = $mech->eval_in_page('lastclick');
    $ok = 1;
};
if (! $triggered) {
    SKIP: { skip "Couldn't get at 'lastclick'. Do you have a Javascript blocker?", 10; };
    exit;
};
ok $triggered, "We have JS enabled";
CLICK_BUBBLE: {
    $mech->click({selector => '#a1', synchronize => 0});
    ($triggered, $type) = $mech->eval_in_page('lastclick');
    is_deeply [@$triggered], ['mydiv1'], 'Click events bubble';
}

@$triggered = ();

CLICK: {
    $mech->click({selector => '#a2', synchronize => 0});
    ($triggered, $type) = $mech->eval_in_page('lastclick');
    is_deeply [@$triggered], ['a2','mydiv2'], "Click events bubble beyond first handler";
}
@$triggered = ();
