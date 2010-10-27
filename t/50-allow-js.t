#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    events => ['DOMContentLoaded', 'load', qw[DOMFrameContentLoaded DOMContentLoaded error abort stop]],
    #log => [qw[debug]],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 3;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';
$mech->autodie(1);

$mech->allow('javascript' => 0);
$mech->get_local('50-click.html');
my ($clicked,$type,$end);
eval {
    ($clicked, $type) = $mech->eval_in_page('clicked');
    $end = 1;
};
like $@, qr//, "JS is disallowed";

$mech->allow('javascript' => 1);
eval {
    ($clicked, $type) = $mech->eval_in_page('clicked');
    $end = 1;
};
ok $clicked, "We found 'clicked'";
