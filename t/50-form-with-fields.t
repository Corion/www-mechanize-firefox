#!/usr/bin/perl -w

# file 50-form3.t
use strict;


use WWW::Mechanize::Firefox;
use Test::More;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 8;
};

$mech->get_local('50-form3.html');
$mech->form_number(1);
my $the_form_dom_node = $mech->current_form;
my $button = $mech->selector('#btn_ok', single => 1);
isa_ok $button, 'MozRepl::RemoteObject::Instance', "The button image";

ok $mech->submit, 'Sent the page';

$mech->get_local('50-form3.html');
$mech->form_id('snd');
ok $mech->current_form, "We can find a form by its id";

$mech->get_local('50-form3.html');
$mech->form_with_fields('r1[name]');
ok $mech->current_form, "We can find a form by its contained input fields (single,matched)";

$mech->get_local('50-form3.html');
$mech->form_with_fields('r1[name]','r2[name]');
ok $mech->current_form, "We can find a form by its contained input fields (double,matched)";

$mech->get_local('50-form3.html');
$mech->form_with_fields('r3name]');
ok $mech->current_form, "We can find a form by its contained input fields (single,closing)";

$mech->get_local('50-form3.html');
$mech->form_with_fields('r4[name');
ok $mech->current_form, "We can find a form by its contained input fields (single,opening)";

$mech->get_local('50-form3.html');
$mech->form_name('snd');
ok $mech->current_form, "We can find a form by its name";

