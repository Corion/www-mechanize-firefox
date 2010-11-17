#!perl -w
use strict;
use WWW::Mechanize::Firefox;
use Time::HiRes;

my $mech = WWW::Mechanize::Firefox->new(
    #log => ['debug'],
);

my ($window, $type) = $mech->eval('window');

print "Going fullscreen\n";
$window->{fullScreen} = 1;

sleep 10;

print "Going back to normal\n";
$window->{fullScreen} = 0;

=head1 NAME

fullscreen.pl - toggle fullscreen mode of Firefox

=head1 SYNOPSIS

fullscreen.pl

=head1 DESCRIPTION

This program switches Firefox into fullscreen mode. It shows
how to access Firefox-internal variables and how to manipulate them.

=cut