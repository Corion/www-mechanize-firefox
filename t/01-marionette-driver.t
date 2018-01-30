#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;
use Firefox::Marionette::Driver;

plan tests => 1;

my $dr = Firefox::Marionette::Driver->new();

$dr->connect()->get;

ok 1;

done_testing;