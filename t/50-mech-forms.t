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
    plan tests => 14;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->get_local('50-click.html');

my $f = $mech->forms;
is ref $f, 'ARRAY', "We got an arrayref of forms";

is 0+@$f, 1, "We found one form";

is $f->[0]->{id}, 'foo', "We found the one form";

my @f = $mech->forms;

is 0+@f, 1, "We found one form";

is $f[0]->{id}, 'foo', "We found the one form";

$mech->get_local('50-form2.html');

$f = $mech->forms;
is ref $f, 'ARRAY', "We got an arrayref of forms";

is 0+@$f, 5, "We found five forms";

is $f->[0]->{id}, 'snd0', "We found the first form";
is $f->[1]->{id}, 'snd', "We found the second form";
is $f->[2]->{id}, 'snd2', "We found the third form";
is $f->[3]->{id}, 'snd3', "We found the fourth form";
is $f->[4]->{id}, 'snd4', "We found the fifth form";

$mech->get_local('51-empty-page.html');
@f = $mech->forms;

is_deeply \@f, [], "We found no forms";

undef $mech;