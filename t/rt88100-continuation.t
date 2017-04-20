#!/usr/bin/perl
use strict;
use WWW::Mechanize::Firefox;
use Test::More tests => 1;
  
my $mech = WWW::Mechanize::Firefox->new(
      #tab => 'current',
);

$mech->get_local('sample.html');

my $lives= eval {
    my $returncode = $mech->status();
    1;
};
ok $lives, "We can fetch HTML that contains the continuation prompt"
    or diag $@;