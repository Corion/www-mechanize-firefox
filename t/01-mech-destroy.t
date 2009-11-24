#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;
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
    plan tests => 2;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';

my $destroyed;
no warnings 'redefine';
*WWW::Mechanize::FireFox::DESTROY = sub {
    $destroyed++
};
undef $mech;
is $destroyed, 1, "Nothing keeps the instance alive";
