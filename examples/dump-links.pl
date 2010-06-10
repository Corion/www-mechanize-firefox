use strict;
use WWW::Mechanize::Firefox;

my $mech = WWW::Mechanize::Firefox->new();
$mech->get_local('links.html');

$mech->highlight_node(
  $mech->selector('a.download'));
  
print $_->{href}, " - ", $_->{innerHTML}, "\n"
  for $mech->selector('a.download');

<>;