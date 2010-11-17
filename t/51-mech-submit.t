#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 1,
    #log => [qw[debug]],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 11;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->get_local('51-mech-submit.html');

my ($triggered,$type,$ok);
eval {
    ($triggered, $type) = $mech->eval_in_page('myevents');
    $ok = 1;
};
if (! $triggered) {
    SKIP: { skip "Couldn't get at 'myevents'. Do you have a Javascript blocker?", 10; };
    exit;
};
ok $triggered, "We have JS enabled";

$mech->allow('javascript' => 1);
$mech->form_id('testform');

$mech->field('q','1');
$mech->submit();

($triggered, $type) = $mech->eval_in_page('myevents');

is $triggered->{action}, 1, 'Action   was triggered';
is $triggered->{submit}, 0, 'OnSubmit was not triggered';
is $triggered->{click},  0, 'Click    was not triggered';

$mech->get_local('51-mech-submit.html');
$mech->allow('javascript' => 1);
$mech->submit_form(
    with_fields => {
        r => 'Hello Firefox',
    },
);
($triggered,$type) = $mech->eval_in_page('myevents');
ok $triggered, "We found 'myevents'";

is $triggered->{action}, 1, 'Action   was triggered';
is $triggered->{submit}, 0, 'OnSubmit was not triggered';
is $triggered->{click},  0, 'Click    was not triggered';

my $r = $mech->xpath('//input[@name="r"]', single => 1 );
is $r->{value}, 'Hello Firefox', "We set the new value";

$mech->get_local('51-mech-submit.html');
$mech->allow('javascript' => 1);
$mech->form_number(1);
$mech->submit_form();
($triggered,$type) = $mech->eval_in_page('myevents');
ok $triggered, "We can submit an empty form";
