#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;
use Net::Protocol::Marionette qw(decode_message encode_message);

my @cases_ok = (
    { name      => 'leading zeroes',
	  canonical => '23:{"value":"Hello World"}',
	  test      => '023:{"value":"Hello World"}',
	  expected  => { value => 'Hello World' },
	  buffer    => '',
	},
    { name      => 'multiple messages',
	  canonical => '23:{"value":"Hello World"}',
	  test      => '23:{"value":"Hello World"}23:{"value":"Hello World"}',
	  expected  => { value => 'Hello World' },
	  buffer    => '23:{"value":"Hello World"}',
	},
    #{ name      => 'leading whitespace',
	#  canonical => '23:{"value":"Hello World"}',
	#  test      => ' 23 : {"value":"Hello World"}',
	#  expected  => { value => 'Hello World' },
	#  buffer    => '',
	#},
);

plan tests => @cases_ok *3;

for my $case (@cases_ok) {
    my $struct = decode_message( \$case->{test} );
	is_deeply $struct, $case->{expected}, $case->{name};
	is        $case->{test}, $case->{buffer}, "We parsed the whole message";
	
	my $encoded = encode_message( $struct );
	is $encoded, $case->{canonical}, "canonical $case->{name}";
};
