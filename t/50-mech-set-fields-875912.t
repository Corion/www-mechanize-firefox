use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 4;
};

my $method = 49;
my $seq = "ARRRSFASDATRASDFSDARASDAGADFGASDRFREWFASCDSAGAREW";

$mech->get_local("50-mech-set-fields-875912.htm");

$mech->form_name('form1');
$mech->set_fields( 'sequence' => $seq );
is $mech->value('sequence'), $seq, "->set_fields sets a single value";

$mech->field( 'sequence' => "xx$seq" );
is $mech->value('sequence'), "xx$seq", "->field also sets a single value";


$mech->set_fields( 'sequence' => "1-$seq", sequence2 => "2-$seq" );
is $mech->value('sequence'), "1-$seq", "->set_fields sets two values";
is $mech->value('sequence2'), "2-$seq", "->set_fields sets two values";
