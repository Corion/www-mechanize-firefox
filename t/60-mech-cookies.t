#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
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

isa_ok $mech, 'WWW::Mechanize::Firefox';

my $cookies = $mech->cookies;
isa_ok $cookies, 'HTTP::Cookies';

# Count how many cookies we get as a test.
my $count = 0;
$cookies->scan(sub{$count++; });

ok $count > 0, 'We found at least one cookie';