#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan skip_all => 'Not yet implemented';
    exit 0;
    
    plan tests => 1;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->repl->expr(<<'JS');
this.oldGetTargetFile = getTargetFile;
alert(getTargetFile);
alert(this.getTargetFile);
/*
getTargetFile = function (aFpP, skipPrompt) {
    alert(aFpP);
    alert(aFpP.fileInfo);
    alert(aFpP.fileInfo.fileExt);
    alert(aFpP.contentType);
    // Fill in aFpP with our canned data
    aFpP.saveAsType = 1; // raw
    aFpP.file = 'C:/Dokumente und Einstellungen/Corion/Desktop/test.html';
    aFpP.fileUri = 'C:/Dokumente und Einstellungen/Corion/Desktop/test.html';
    return true;
}
*/
JS

my ($site,$estatus) = ('http://www.firefox-start.com/download/Firefox%20Setup%203.0.3.exe',200);
my $res = $mech->get($site);

$mech->repl->expr(<<'JS');
/*
getTargetFile = this.oldGetTargetFile;
*/
JS
