#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Test::More tests => 2;

my $firefox = WWW::Mechanize::Firefox->new(tab => 'current');
$firefox->get_local('form2.html');
$firefox->form_number(1);
my $the_form_dom_node = $firefox->current_form;
my $button = $firefox->selector('#btn_ok', single => 1);
isa_ok $button, 'MozRepl::RemoteObject::Instance', "The button image";

ok $firefox->submit, 'Sent the page';
