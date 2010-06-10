use strict;
use WWW::Mechanize::Firefox;

my $mech = WWW::Mechanize::Firefox->new();
$mech->get_local('links.html');

$mech->eval_in_page(<<'JS');
    alert('Hallo Frankfurt.pm');
JS

<>;