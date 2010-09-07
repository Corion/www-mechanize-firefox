#!perl -w
use strict;
use Test::More;
use File::Basename;
use vars '$mech';

#use WWW::Mechanize::Firefox::DSL;
BEGIN {
    require WWW::Mechanize::Firefox::DSL;
    
    my $ok = eval { 
        WWW::Mechanize::Firefox::DSL->import(
            autodie => 0,
            #log => [qw[debug]]
        );
        1
    };
    die "Import failure: $@"
        unless $ok;
};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 1;
};

get_local '49-mech-get-file.html';
is title, '49-mech-get-file.html', 'We opened the right page';
diag ct;
diag uri;

undef $mech;