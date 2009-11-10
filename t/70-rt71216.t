#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::FireFox;

my $mech = eval { WWW::Mechanize::FireFox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 3;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';

my $res = eval { $mech->get('http://www.hotmail.com'); 1 };
my $err = $@;
is $res, 1, 'Got Hotmail OK';
is $err, "", 'No fatal errors';
