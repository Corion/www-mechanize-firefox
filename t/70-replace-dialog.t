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
    plan tests => 1;
};

# Now we need to have a server that sends us content with
# Content-Disposition: attachment; filename="foo.bar"
my $url = "";

# Now, replace the @mozilla.org/filepicker with our own
# replacement
my $cc = $mech->eval(<<'JS');
        Components.classes
JS

my $cc_filepicker = $mech->eval(<<'JS');
        Components.classes["@mozilla.org/filepicker;1"]
JS

my $fake_filepicker = $mech->eval(<<'JS');
        var fp = Components.classes["@mozilla.org/filepicker;1"];
        Components.classes["@mozilla.org/filepicker;1"] = {
            createInstance: function(i) {
                alert("new dialog");
                return fp.createInstance(i);
            },
        };
JS

print "Please press CTRL+S";
<>;

# Restore original filepicker
$cc->{'@mozilla.org/filepicker;1'} = $cc_filepicker;