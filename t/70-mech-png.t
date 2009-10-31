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

#$mech->get('http://corion.net');
$mech->content(<<'HTML');
<html>
<head><title>Hello PNG!</title></head>
<body>
Hello <b>PNG</b>!
</body>
</html>
HTML

ok $mech->success, 'We got the page';

my $pngData = $mech->content_as_png();

like $pngData, '/^.PNG/', "The result looks like a PNG format file";
