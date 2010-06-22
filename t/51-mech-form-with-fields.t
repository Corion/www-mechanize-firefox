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
    plan tests => 5;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->get_local('51-mech-submit.html');
my $f = $mech->form_with_fields(
   'r',
);
ok $f, "We found the form";

$mech->get_local('51-mech-submit.html');
$f = $mech->form_with_fields(
   'q','r',
);
ok $f, "We found the form";

$mech->get_local('52-frameset.html');
$f = $mech->form_with_fields(
   'baz','bar',
);
ok $f, "We found the form in a frame";

$mech->get_local('52-iframeset.html');
$f = $mech->form_with_fields(
   'baz','bar',
);
ok $f, "We found the form in a frame";
