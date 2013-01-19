#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

use t::helper;

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 15*2;
};

my $mech=
    WWW::Mechanize::Firefox->new(
        autodie => 1,
        #log => [qw[debug]],
    );

for my $i (['direct','51-mech-submit.html'],['frame','51-mech-field-frameset.html']) {
   my ($info,$page) = @$i;
   diag "Loading $page";

   $mech->get_local($page);
   $mech->form_id('testform');
   is $mech->value('q'), 'Hello World a', "We retrieve a value for plain names";
   is $mech->value('fancy:t'), 'A fancy value 1', "We retrieve a value for fancy names too";
   
   my $lived = eval {
      $mech->field( q => 'q' );
      $mech->field( "fancy:t" => 'Another fancy value' );
      1
   };
   ok $lived, "We can set field 'q' ($info)";
   is $mech->value('q'), 'q', "We retrieve our value";
   is $mech->value( "fancy:t"), 'Another fancy value', "... and the fancy one too";

   $mech->form_id('testform2');
   is $mech->value('q'), 'Hello World b', "We retrieve a value for plain names";
   is $mech->value('fancy:t'), 'A fancy value 2', "We retrieve our value for fancy names too";
   $lived = eval {
      $mech->field( r => 'r' );
      $mech->field( q => 'q' );
      $mech->field( "fancy:t" => 'Another fancy value' );
      1
   };
   is $mech->value('r'), 'r', "We retrieve our value for r";
   is $mech->value('q'), 'q', "We retrieve our value for q";
   is $mech->value( "fancy:t" ), 'Another fancy value', "... and the fancy one too";

   $mech->get_local($page);
   $mech->form_id('testform');
   is $mech->value('q'), 'Hello World a', "We retrieve a value for plain names";
   is $mech->value('fancy:t'), 'A fancy value 1', "We retrieve our value for fancy names too";
   $lived = eval {
      $mech->field( r => 'r' );
      1
   };
   ok !$lived, "We don't find field 'r' in #testform";
   
   $mech->get_local($page);
   $mech->form_id('testform');
   $mech->set_visible("value1", "value2");
   is $mech->value('q'), 'value1', "->set_visible on first field";
   is $mech->value('fancy:t'), 'value2', "->set_visible on second field";
};
