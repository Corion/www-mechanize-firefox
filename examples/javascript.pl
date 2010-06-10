use strict;
use WWW::Mechanize::FireFox;

my $mech = WWW::Mechanize::FireFox->new();
$mech->get_local('links.html');

$mech->eval_in_page(<<'JS');
    alert('Hallo Frankfurt.pm');
JS

<>;