#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 1+2*2;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

for my $i (['direct','51-mech-submit.html'],['frame','51-mech-field-frameset.html']) {
    my ($info,$page) = @$i;

    $mech->get_local($page);
    my $lived = eval {
       $mech->field( r => 'r' );
       1
    };
    ok $lived, "We can set field 'r' ($info)";
    is $mech->value('r'), 'r', "We retrieve our value";
};