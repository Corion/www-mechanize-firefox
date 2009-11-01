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
    plan tests => 4;
};

isa_ok $mech, 'WWW::Mechanize::FireFox';

#$mech->get('http://corion.net');
$mech->update_html(<<'HTML');
<html>
<head><title>Hello PNG!</title></head>
<body>
Hello <b id="my_name">PNG</b>!
</body>
</html>
HTML

ok $mech->success, 'We got the page';

my $pngData = $mech->content_as_png();

like $pngData, '/^.PNG/', "The result looks like a PNG format file";

my $pngName = $mech->selector("#my_name", single => 1);
$pngData = $mech->element_as_png($pngName);
like $pngData, '/^.PNG/', "The result looks like a PNG format file";

open my $fh, '>', 'tmp.png' or die;
binmode $fh;
print {$fh} $pngData;