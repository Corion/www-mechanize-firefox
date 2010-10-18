#!perl -w
use strict;
use Test::More;
use File::Basename;

#use WWW::Mechanize::Firefox::DSL;
BEGIN {
    my $err;
    require WWW::Mechanize::Firefox::DSL;
    my $ok = eval { 
        WWW::Mechanize::Firefox::DSL->import(
            autodie => 0,
            #log => [qw[debug]]
        );
        1
    };
    $err ||= $@;
    
    if (!$ok || $err) {
        plan skip_all => "Couldn't connect to MozRepl: $@";
        exit
    } else {
        plan tests => 2;
    };
};


get_local '49-mech-get-file.html';
is title, '49-mech-get-file.html', 'We opened the right page';
is ct, 'text/html', "Content-Type is text/html";
diag uri;

undef $mech;