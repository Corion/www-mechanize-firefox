use strict;
use WWW::Mechanize::FireFox;

my $mech = WWW::Mechanize::FireFox->new();
$mech->get_local('links.html');

$mech->highlight_node(
  $mech->selector('a.download'));
  
print $_->{href}, " - ", $_->{innerHTML}, "\n"
  for $mech->selector('a.download');

<>;