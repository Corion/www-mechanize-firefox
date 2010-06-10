use strict;
use WWW::Mechanize::Firefox;

my $mech = WWW::Mechanize::Firefox->new();
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