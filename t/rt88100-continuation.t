#!/usr/bin/perl
use strict;
use WWW::Mechanize::Firefox;
use Test::More tests => 1;
  
my $mech = eval { $mech = WWW::Mechanize::Firefox->new(
      #tab => 'current',
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 1;
};

$mech->get_local('sample.html');

my $lives= eval {
    my $returncode = $mech->status();
    1;
};
ok $lives, "We can fetch HTML that contains the continuation prompt"
    or diag $@;