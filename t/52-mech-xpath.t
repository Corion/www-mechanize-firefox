#!perl -w
use strict;
use Test::More tests => 2;
use WWW::Mechanize::FireFox;

my $mech = WWW::Mechanize::FireFox->new( 
    autodie => 0,
    #log => [qw[debug]]
);
isa_ok $mech, 'WWW::Mechanize::FireFox';

my $content = <<HTML;
<html>
<head>
<title>Hello FireFox!</title>
</head>
<body>
<h1>Hello <b>World</b>!</h1>
<p>Hello <b>WWW::Mechanize::FireFox</b></p>
</body>
</html>
HTML

$mech->set_content($content);

my $c = $mech->content;
for ($c,$content) {
    s/\s+/ /msg; # normalize whitespace
    s/> </></g;
    s/\s*$//;
};

my @n = $mech->document->__xpath('//b');
is scalar @n, 2, 'Querying stuff via XPath works';


