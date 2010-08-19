#!perl -w

#use warnings;
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

BEGIN {
    delete @ENV{qw(PATH IFS CDPATH ENV BASH_ENV)};  # Placates taint-unsafe Cwd.pm in 5.6.1
}

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 20;
};
isa_ok( $mech, 'WWW::Mechanize::Firefox' );

#my $uri = URI::file->new_abs( 't/select.html' )->as_string;
my $response = $mech->get_local( 'select.html' );
ok( $response->is_success, "Fetched select.html" );

my ($sendsingle, @sendmulti, %sendsingle, %sendmulti,
    $rv, $return, @return, @singlereturn, $form);
# possible values are: aaa, bbb, ccc, ddd
$sendsingle = 'aaa';
@sendmulti = qw(bbb ccc);
@singlereturn = ($sendmulti[0]);
%sendsingle = (n => 1);
%sendmulti = (n => [2, 3]);

ok($mech->form_number(1), 'set form to number 1');
$form = $mech->current_form();

# Multi-select

# pass multiple values to a multi select
$mech->select('multilist', \@sendmulti);
@return = $mech->value('multilist');
is_deeply(\@return, \@sendmulti, 'multi->multi value is ' . join(' ', @sendmulti));

$response = $mech->get_local( 'select.html' );
ok( $response->is_success, "Fetched select.html" );
$mech->select('multilist', \%sendmulti);
@return = $mech->value('multilist');
is_deeply(\@return, \@sendmulti, 'multi->multi value is ' . join(' ', @sendmulti));

# pass a single value to a multi select
$response = $mech->get_local( 'select.html' );
ok( $response->is_success, "Fetched select.html" );
$mech->select('multilist', $sendsingle);
#$return = $form->param('multilist');
$return = $mech->value('multilist');
is($return, $sendsingle, "single->multi value is '$sendsingle'");

$response = $mech->get_local( 'select.html' );
ok( $response->is_success, "Fetched select.html" );
$mech->select('multilist', \%sendsingle);
$return = $mech->value('multilist');
is($return, $sendsingle, "single->multi value is '$sendsingle'");


# Single select

# pass multiple values to a single select (only the _first_ should be set)
$response = $mech->get_local( 'select.html' );
ok( $response->is_success, "Fetched select.html" );
$mech->select('singlelist', \@sendmulti);
@return = $mech->value('singlelist');
is_deeply(\@return, \@singlereturn, 'multi->single value is ' . join(' ', @singlereturn));

$response = $mech->get_local( 'select.html' );
ok( $response->is_success, "Fetched select.html" );
$mech->select('singlelist', \%sendmulti);
@return = $mech->value('singlelist');
is_deeply(\@return, \@singlereturn, 'multi->single value is ' . join(' ', @singlereturn));


# pass a single value to a single select
$response = $mech->get_local( 'select.html' );
ok( $response->is_success, "Fetched select.html" );
$rv = $mech->select('singlelist', $sendsingle);
$return = $mech->value('singlelist');
is($return, $sendsingle, "single->single value is '$sendsingle'");

$response = $mech->get_local( 'select.html' );
ok( $response->is_success, "Fetched select.html" );
$rv = $mech->select('singlelist', \%sendsingle);
$return = $mech->value('singlelist');
is($return, $sendsingle, "single->single value is '$sendsingle'");

# test return value from $mech->select
is($rv, 1, 'return 1 after successful select');

EAT_THE_WARNING: { # Mech complains about the non-existent field
    local $SIG{__WARN__} = sub {};
    $rv = $mech->select('missing_list', 1);
}
is($rv, undef, 'return undef after failed select');
