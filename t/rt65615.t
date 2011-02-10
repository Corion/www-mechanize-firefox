use strict;
use WWW::Mechanize::Firefox;
use Test::More tests => 1;

my $f = WWW::Mechanize::Firefox->new(
  launch      => 'firefox',
  tab         => 'current',
  agent_alias => 'Linux Mozilla',
);

$f->get_local('rt65615.html');
ok eval {
    my $img = $f->content_as_png;
    1
} or diag $@;
