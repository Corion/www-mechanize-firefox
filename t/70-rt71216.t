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

my $res = eval { $mech->get_local('70-rt71216.html'); 1 };
my $err = $@;
is $res, 1, 'Got Hotmail OK';
is $err, "", 'No fatal errors';
