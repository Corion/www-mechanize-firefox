#!perl -w
use strict;
use Test::More;
use File::Basename;
use vars '$mech';

#use WWW::Mechanize::Firefox::DSL;
BEGIN {
    my $err;
    my $ok = eval {
        require mro;
        1
    };
    $err = $@;
    if ($ok) {
        require WWW::Mechanize::Firefox::DSL;
        $ok = eval { 
            WWW::Mechanize::Firefox::DSL->import(
                autodie => 0,
                #log => [qw[debug]]
            );
            1
        };
        $err ||= $@;
    };
    
    if (!$ok || $err) {
        plan skip_all => "Couldn't connect to MozRepl: $@";
        exit
    } else {
        plan tests => 2;
    };
};


get_local '49-mech-get-file.html';
is title, '49-mech-get-file.html', 'We opened the right page';
is ct, 'text/html';
diag uri;

undef $mech;