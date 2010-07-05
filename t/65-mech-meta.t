#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 3;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->allow( metaredirects => 0 );
$mech->get_local('65-mech-meta.html');
sleep 1; # just in case
is $mech->title, '65-mech-meta.html', 'We can prohibit META redirects';

$mech->allow( metaredirects => 1 );
$mech->get_local('65-mech-meta.html');
sleep 1; # just in case
is $mech->title, '49-mech-get-file.html', 'We can allow META redirects';
