#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::FireFox;

my $mech = eval { WWW::Mechanize::FireFox->new( 
    autodie => 0,
    #log => [qw[debug]]
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 3;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';

$mech->get('http://corion.net');

ok $mech->success, 'We got the page';

my $pngData = $mech->content_as_png();

open my $fh, '>', 'test.png'
    or die "Couldn't create 'test.png': $!";
binmode $fh;
print {$fh} $pngData;