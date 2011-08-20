#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;
use URI::file;
use Cwd;
use File::Basename;

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

my $next = 'http://www.google.com/services/';
my $res = eval { 
    for (1..25) {
    printf "getting '$next'\n",
        $mech->get($next, synchronize => 0);
        my $png = $mech->content_as_png();
    };
    1;
};
my $err = $@;
is $res, 1, 'Got Pages OK';
is $err, "", 'No fatal errors';
