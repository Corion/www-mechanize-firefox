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
    plan tests => 19;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';
$mech->autodie(1);

$mech->get_local('50-tick.html');

my ($clicked,$type,$ok);

sub to_string($) {
      $_[0] eq 'true' ? 1
    : $_[0] eq 'false' ? 0
    : $_[0] eq '0' ? 0
    : $_[0] eq '1' ? 1
    : "unknown truth value $_[0]"
    ;
};

# Xpath
$mech->get_local('50-tick.html');
is to_string $mech->selector('#unchecked_1',single => 1)->{checked},0, "#unchecked_1 is not checked";
$mech->tick('#unchecked_1');
is to_string $mech->selector('#unchecked_1',single => 1)->{checked},1, "#unchecked_1 is now checked";

$mech->get_local('50-tick.html');
is to_string $mech->selector('#unchecked_1',single => 1)->{checked},0, "#unchecked_1 is not checked";
$mech->tick('unchecked',3);
is to_string $mech->selector('#unchecked_1',single => 1)->{checked},0, "#unchecked_1 is not checked"
    or diag $mech->selector('#unchecked_1',single => 1)->{checked};
is to_string $mech->selector('#unchecked_3',single => 1)->{checked},1,  "#unchecked_3 is now checked"
    or diag $mech->selector('#unchecked_3',single => 1)->{checked};

$mech->get_local('50-tick.html');
is to_string $mech->selector('#unchecked_1',single => 1)->{checked},0, "#unchecked_1 is not checked";
$mech->tick('unchecked',1);
is to_string $mech->selector('#unchecked_1',single => 1)->{checked},1,  "#unchecked_1 is now checked";
is to_string $mech->selector('#unchecked_3',single => 1)->{checked},0, "#unchecked_3 is not checked";

# Now check not setting things
$mech->get_local('50-tick.html');
is to_string $mech->selector('#unchecked_1',single => 1)->{checked},0, "#unchecked_1 is not checked";
$mech->tick('unchecked',1,0);
is to_string $mech->selector('#unchecked_1',single => 1)->{checked},0, "#unchecked_1 is not checked";
is to_string $mech->selector('#unchecked_3',single => 1)->{checked},0, "#unchecked_3 is not checked";

# Now check removing checkmarks
$mech->get_local('50-tick.html');
is to_string $mech->selector('#prechecked_1',single => 1)->{checked},1, "#prechecked_1 is checked";
$mech->tick('prechecked',1,0);
is to_string $mech->selector('#prechecked_1',single => 1)->{checked},0, "#prechecked_1 is not checked";
is to_string $mech->selector('#prechecked_3',single => 1)->{checked},1, "#prechecked_3 is still checked";

# Now check removing checkmarks
$mech->get_local('50-tick.html');
is to_string $mech->selector('#prechecked_1',single => 1)->{checked},1, "#prechecked_1 is checked";
is to_string $mech->selector('#prechecked_3',single => 1)->{checked},1, "#prechecked_3 is checked";
$mech->untick('prechecked',3);
is to_string $mech->selector('#prechecked_1',single => 1)->{checked},1, "#prechecked_1 is still checked";
is to_string $mech->selector('#prechecked_3',single => 1)->{checked},0, "#prechecked_3 is not checked";
