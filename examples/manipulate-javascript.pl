use strict;
use WWW::Mechanize::FireFox;

my $mech = WWW::Mechanize::FireFox->new();
$mech->get_local('javascript.html');

my ($val,$type) = $mech->eval_in_page(<<'JS');
    secret
JS

if ($type ne 'string') {
    die "Unbekannter Ergebnistyp: $type";
};
print "Das Kennwort ist $val";

$mech->value('pass',$val);

<>;