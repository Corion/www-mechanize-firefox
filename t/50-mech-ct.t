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
    plan tests => 2;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';

#my ($site,$estatus) = ('http://doesnotexit.example',500);
#\my ($site,$estatus) = ('http://corion.net/test',200);
#my $status = $mech->get($site);

is $mech->ct, 'text/html', "Content-type";

