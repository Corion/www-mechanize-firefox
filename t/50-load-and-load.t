#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Test::More;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 2;
};

$mech->get_local('50-form2.html');
ok 1, "We loaded the page";

#sleep 10;

$mech->get_local('50-form2.html');
ok 1, "We loaded the page, again, and don't hang";

#sleep 100;