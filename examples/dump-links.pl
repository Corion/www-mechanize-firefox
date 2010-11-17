#!perl -w
use strict;
use WWW::Mechanize::Firefox;

my $mech = WWW::Mechanize::Firefox->new();
$mech->get_local('links.html');

$mech->highlight_node(
  $mech->selector('a.download'));
  
print $_->{href}, " - ", $_->{innerHTML}, "\n"
  for $mech->selector('a.download');

<>;

=head1 NAME

dump-links.pl - Dump links on a webpage

=head1 SYNOPSIS

dump-links.pl

=head1 DESCRIPTION

This program demonstrates how to read elements out of the Firefox
DOM and how to get at text within nodes.

It also demonstrates how you can modify elements in a webpage.

=cut