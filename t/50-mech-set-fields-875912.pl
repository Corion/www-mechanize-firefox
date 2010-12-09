use strict;
use Test::More;
use WWW::Mechanize::Firefox;

plan tests => 4;

my $agent = WWW::Mechanize::Firefox->new();

my $method = 49;
my $seq = "ARRRSFASDATRASDFSDARASDAGADFGASDRFREWFASCDSAGAREW";

$agent->get_local("50-mech-set-fields-875912.htm");

$agent->form_name('form1');
$agent->set_fields( 'sequence' => $seq );
is $agent->value('sequence'), $seq, "->set_fields sets a single value";

$agent->field( 'sequence' => "xx$seq" );
is $agent->value('sequence'), "xx$seq", "->field also sets a single value";


$agent->set_fields( 'sequence' => "1-$seq", sequence2 => "2-$seq" );
is $agent->value('sequence'), "1-$seq", "->set_fields sets two values";
is $agent->value('sequence2'), "2-$seq", "->set_fields sets two values";
