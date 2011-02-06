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
    plan tests => 1+8*2;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

for my $i (['direct','51-mech-submit.html'],['frame','51-mech-field-frameset.html']) {
    my ($info,$page) = @$i;

    $mech->get_local($page);
    $mech->form_id('testform');
    is $mech->value('q'), 'Hello World a', "We retrieve a value for plain names";
    is $mech->value('fancy:t'), 'A fancy value 1', "We retrieve a value for fancy names too";
    
    my $lived = eval {
       $mech->field( q => 'q' );
       1
    };
    ok $lived, "We can set field 'q' ($info)";
    is $mech->value('q'), 'q', "We retrieve our value";

    $mech->form_id('testform2');
    is $mech->value('q'), 'Hello World b', "We retrieve a value for plain names";
    $lived = eval {
       $mech->field( r => 'r' );
       $mech->field( q => 'q' );
       1
    };
    is $mech->value('r'), 'r', "We retrieve our value for r";
    is $mech->value('q'), 'q', "We retrieve our value for q";
    
    is $mech->value('fancy:t'), 'A fancy value 2', "We retrieve our value for fancy names too";
};