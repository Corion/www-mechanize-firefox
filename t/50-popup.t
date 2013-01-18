#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

plan skip_all => "Opening windows are not yet tracked";
exit;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #events => [ 'DOMWindowOpened', 'DOMContentLoaded', 'load'], # domwindowclosed
    # then add a window.onload handler to check whether it's a new browser
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 16;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';
$mech->autodie(1);

$mech->get_local('50-click.html');
$mech->allow('javascript' => 1);

my ($win,$type,$ok);

eval {
    ($win, $type) = $mech->eval_in_page('open_window');
    $ok = 1;
};

if (! $win) {
    SKIP: { skip "Couldn't get at 'open_window'. Do you have a Javascript blocker?", 15; };
    exit;
};

ok $win, "We found 'open_window'";
$mech->click($win, synchronize => 0);
ok 1, "We get here";
diag "But we don't know what window was opened";
# or how to close it
