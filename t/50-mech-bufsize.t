#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    bufsize => 10_000_000,
    #log => ['debug'],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 8;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';
my $response;
my $result = eval {
    $response = $mech->get('http://cmcc.deviantart.com/', no_cache => 1); # a large website
    1
};
ok $result, "We lived through the call";
is $@, '', "... and we got no error";
ok $mech->success(), "... and we consider the response a success";
isa_ok $response, 'HTTP::Response', '... and we got a good respone';

my $png;
$result = eval {
    $png = $mech->content_as_png;
    1;
};
ok $result, "We lived through the call";
is $@, '', "... and we got no error";
like $png, qr/^.PNG/, "... and the result looks like a PNG image";

