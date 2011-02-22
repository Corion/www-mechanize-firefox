#!/usr/bin/perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]]
    timeout=>60,
    bufsize => 50_000_000,
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 3;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

diag time." get #1\n";
$mech->get('http://cmcc.deviantart.com/');
diag time." after get #1\n";

diag time." content #1\n";
my $con=$mech->content();
diag time." after content #1\n";

my $time = time;
diag "$time get #2\n";
$mech->get('http://cmcc.deviantart.com/#/d1a8l1t');
diag time." after get #2\n";
cmp_ok time - $time, '<', 20,
    "We fetch a page in under 20 seconds";

$time = time;
diag "$time content #2\n";
$con=$mech->content();
diag time." after content #2\n";
cmp_ok time - $time, '<', 20,
    "We fetch a page in under 20 seconds";
