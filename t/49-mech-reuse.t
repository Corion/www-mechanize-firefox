#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    autoclose => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 7;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->get_local('49-mech-get-file.html');
ok $mech->success, '49-mech-get-file.html';
is $mech->title, '49-mech-get-file.html', "We loaded the right file";

undef $mech;

$mech = eval { WWW::Mechanize::Firefox->new(
    tab => qr/^\Q49-mech-get-file.html/,
    autoclose => 1,
    #log => [qw[debug]]
)};
is $@, '';
isa_ok $mech, 'WWW::Mechanize::Firefox';
undef $mech;

$mech = eval { WWW::Mechanize::Firefox->new(
    tab => qr/^\Q49-mech-get-file.html/,
)};
is $mech, undef, "If a tab doesn't exist, that's fatal";

$mech = eval { WWW::Mechanize::Firefox->new(
    tab => qr/^\Q49-mech-get-file.html/,
    create => 1,
    autoclose => 1,
    #log => [qw[debug]]
)};
# but we can (re)create it
isa_ok $mech, 'WWW::Mechanize::Firefox';
undef $mech;
