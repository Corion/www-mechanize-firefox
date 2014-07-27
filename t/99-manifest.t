use strict;
use Test::More;

# Check that MANIFEST and MANIFEST.skip are sane :

use File::Find;
use File::Spec;

my @files = qw( MANIFEST MANIFEST.SKIP );
plan tests => scalar @files * 4 
              +1 # MANIFEST existence check
              ;

for my $file (@files) {
  ok(-f $file, "$file exists");
  open F, "<$file"
    or die "Couldn't open $file : $!";
  my @lines = <F>;
  is_deeply([grep(/^$/, @lines)],[], "No empty lines in $file");
  is_deeply([grep(/^\s+$/, @lines)],[], "No whitespace-only lines in $file");
  is_deeply([grep(/^\s*\S\s+$/, @lines)],[],"No trailing whitespace on lines in $file");
  
  if ($file eq 'MANIFEST') {
    chomp @lines;
    is_deeply([grep { s/\s.*//; ! -f } @lines], [], "All files in $file exist")
        or do { diag "$_ is mentioned in $file but doesn't exist on disk" for grep { ! -f } @lines };
  };
  
  close F;
};

