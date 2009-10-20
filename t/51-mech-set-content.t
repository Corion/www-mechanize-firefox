#!perl -w
use strict;
use Test::More tests => 2;
use WWW::Mechanize::FireFox;

my $mech = WWW::Mechanize::FireFox->new( autodie => 0, log => [qw[debug]] );
isa_ok $mech, 'WWW::Mechanize::FireFox';

my $content = <<HTML;
<html>
<head>
<title>Hello FireFox!</title>
</head>
<body>
<p>Hello WWW::Mechanize::FireFox</p>
</body>
</html>
HTML

$mech->set_content($content);
#$mech->tab->__release_action('');

is $mech->content, $content, "Setting the content works";

