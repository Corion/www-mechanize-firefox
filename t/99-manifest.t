use strict;
use Test::More;

# Check that MANIFEST and MANIFEST.skip are sane :

use File::Find;
use File::Spec;

my @files = qw( MANIFEST MANIFEST.skip );
plan tests => scalar @files * 4;

for my $file (@files) {
  ok(-f $file, "$file exists");
  open F, "<$file"
    or die "Couldn't open $file : $!";
  my @lines = <F>;
  is_deeply([grep(/^$/, @lines)],[], "No empty lines in $file");
  is_deeply([grep(/^\s+$/, @lines)],[], "No whitespace-only lines in $file");
  is_deeply([grep(/^\s*\S\s+$/, @lines)],[],"No trailing whitespace on lines in $file");
  close F;
};

