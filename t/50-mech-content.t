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
    plan tests => 5;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

my $html = $mech->content;
like $html, qr!<html><head>(<title></title>)?</head><body>WWW::Mechanize::Firefox</body></html>!, "We can get the plain HTML";

my $html2 = $mech->content( format => 'html' );
is $html2, $html, "When asking for HTML explicitly, we get the same text";

my $text = $mech->content( format => 'text' );
is $text, 'WWW::Mechanize::Firefox', "We can get the plain text";

my $text2;
my $lives = eval { $mech->content( format => 'bogus' ); 1 };
ok !$lives, "A bogus content format raises an error";
