#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    events => ['DOMContentLoaded', 'load', qw[DOMFrameContentLoaded DOMContentLoaded error abort stop]],
    #log => [qw[debug]],
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 19;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';
$mech->autodie(1);

$mech->get_local('50-tick.html');

my ($clicked,$type,$ok);

# Xpath
$mech->get_local('50-tick.html');
is $mech->selector('#unchecked_1',single => 1)->{checked},'false', "#unchecked_1 is not checked";
$mech->tick('#unchecked_1');
is $mech->selector('#unchecked_1',single => 1)->{checked},'true', "#unchecked_1 is now checked";

$mech->get_local('50-tick.html');
is $mech->selector('#unchecked_1',single => 1)->{checked},'false', "#unchecked_1 is not checked";
$mech->tick('unchecked',3);
is $mech->selector('#unchecked_1',single => 1)->{checked},'false', "#unchecked_1 is not checked";
is $mech->selector('#unchecked_3',single => 1)->{checked},'true',  "#unchecked_3 is now checked";

$mech->get_local('50-tick.html');
is $mech->selector('#unchecked_1',single => 1)->{checked},'false', "#unchecked_1 is not checked";
$mech->tick('unchecked',1);
is $mech->selector('#unchecked_1',single => 1)->{checked},'true',  "#unchecked_1 is now checked";
is $mech->selector('#unchecked_3',single => 1)->{checked},'false', "#unchecked_3 is not checked";

# Now check not setting things
$mech->get_local('50-tick.html');
is $mech->selector('#unchecked_1',single => 1)->{checked},'false', "#unchecked_1 is not checked";
$mech->tick('unchecked',1,0);
is $mech->selector('#unchecked_1',single => 1)->{checked},'false', "#unchecked_1 is not checked";
is $mech->selector('#unchecked_3',single => 1)->{checked},'false', "#unchecked_3 is not checked";

# Now check removing checkmarks
$mech->get_local('50-tick.html');
is $mech->selector('#prechecked_1',single => 1)->{checked},'true', "#prechecked_1 is checked";
$mech->tick('prechecked',1,0);
is $mech->selector('#prechecked_1',single => 1)->{checked},'false', "#prechecked_1 is not checked";
is $mech->selector('#prechecked_3',single => 1)->{checked},'true', "#prechecked_3 is still checked";

# Now check removing checkmarks
$mech->get_local('50-tick.html');
is $mech->selector('#prechecked_1',single => 1)->{checked},'true', "#prechecked_1 is checked";
is $mech->selector('#prechecked_3',single => 1)->{checked},'true', "#prechecked_3 is checked";
$mech->untick('prechecked',3);
is $mech->selector('#prechecked_1',single => 1)->{checked},'true', "#prechecked_1 is still checked";
is $mech->selector('#prechecked_3',single => 1)->{checked},'false', "#prechecked_3 is not checked";
