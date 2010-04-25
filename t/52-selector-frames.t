#!perl -w
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
    plan tests => 11;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->get_local('52-frameset.html');

my @content = $mech->xpath('//*[@id="content"]', frames => 1);
is scalar @content, 1, 'Querying of subframes returns results';
is $content[0]->{innerHTML}, '52-subframe.html', "We get the right frame";

@content = $mech->selector('#content', frames => 1);
is scalar @content, 1, 'Querying of subframes returns results via CSS selectors too';
is $content[0]->{innerHTML}, '52-subframe.html', "We get the right frame";

$mech->get_local('52-iframeset.html');

@content = $mech->xpath('//*[@id="content"]', frames => 1);
is scalar @content, 2, 'Querying of subframes returns results';
is $content[0]->{innerHTML}, '52-iframeset.html', "We get the right frame";
is $content[1]->{innerHTML}, '52-subframe.html', "We get the right frame";

@content = $mech->selector('#content', frames => 1);
is scalar @content, 2, 'Querying of subframes returns results via CSS selectors too';
is $content[0]->{innerHTML}, '52-iframeset.html', "We get the right frame";
is $content[1]->{innerHTML}, '52-subframe.html', "We get the right frame";