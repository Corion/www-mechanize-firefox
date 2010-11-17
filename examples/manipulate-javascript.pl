#!perl -w
use strict;
use WWW::Mechanize::Firefox;

my $mech = WWW::Mechanize::Firefox->new();
$mech->get_local('javascript.html');

my ($val,$type) = $mech->eval_in_page(<<'JS');
    secret
JS

if ($type ne 'string') {
    die "Unbekannter Ergebnistyp: $type";
};
print "Das Kennwort ist $val";

$mech->value('pass',$val);

<>;

=head1 NAME

manipulate-javascript.pl - demonstrate how to manipulate Javascript in a page

=head1 SYNOPSIS

manipulate-javascript.pl

=head1 DESCRIPTION

This program demonstrates that you have write access to Javascript
variables in Firefox and in webpages displayed through Firefox.

=cut