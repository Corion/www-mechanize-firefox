#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    bufsize => 1025, # a too small size, but still larger than the Net::Telnet default
    #log => ['debug'],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 3;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';
my $response;
my $result = eval {
    $response = $mech->get('http://perl.org/', no_cache => 1); # a large website
    1
};
ok !$result, "We died on the call";
like $@, qr/1025/, "... and we got the correct bufsize error";
