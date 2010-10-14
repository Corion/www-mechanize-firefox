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
    plan tests => 16;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';
$mech->autodie(1);

$mech->get_local('50-tick.html');

my ($clicked,$type,$ok);

# Xpath
$mech->get_local('50-tick.html');
$mech->tick('#unchecked');
is $mech->value('#unchecked'),2, "->tick() with an xpath id selector works";

$mech->get_local('50-tick.html');
$mech->tick('unchecked_1','3');
is $mech->value('unchecked'),3, "->tick() with a name and value works";
is $mech->value('#unchecked'),3, "->tick() with a name and value works";
