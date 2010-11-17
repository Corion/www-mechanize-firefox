#!perl -w
use strict;
use WWW::Mechanize::Firefox;

my $mech = WWW::Mechanize::Firefox->new();
$mech->get_local('links.html');

$mech->eval_in_page(<<'JS');
    alert('Hallo Frankfurt.pm');
JS

<>;

=head1 NAME

javascript.pl - execute Javascript in a page

=head1 SYNOPSIS

javascript.pl

=head1 DESCRIPTION

B<This program> demonstrates how to execute simple
Javascript in a page.

=cut