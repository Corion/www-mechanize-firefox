#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Test::More;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 1,
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 7;
};

$mech->get_local('51-form-number-blakew.html');
is $mech->current_form, undef, "At start, we have no current form";
my $lives = eval {
    $mech->form_number(1);
    1
};
ok $lives, 'We can select the first form';
is $@, '', 'No error when selecting the first form';
is $mech->current_form->{id}, 'Form_1', 'We selected the correct form';

$lives = eval {
    $mech->form_number(2);
    1
};
ok $lives, 'We can select the second form';
is $@, '', 'No error when selecting the second form';
is $mech->current_form->{id}, 'Form_2', 'We selected the correct form';
