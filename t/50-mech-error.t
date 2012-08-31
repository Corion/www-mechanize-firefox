#!perl -w
use strict;
use Test::More;
use File::Basename;

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
    plan tests => 2;
};

#line 2 "foo"
is eval { $mech->eval_in_page('bar'); 1 }, undef, "Invalid JS gives an error";
my $err = $@;
like $err, qr/\bat foo line 2\b/, "the correct location gets flagged as error";

undef $mech; # and close that tab
