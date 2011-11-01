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
    plan tests => 6;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->get_local('52-selector-relative.html');

my $content = $mech->selector( '#content', single => 1 );

my @found = $mech->selector( '.child', node => $content );
is 0+@found, 1, "We find one child"
    or do { diag $_->{innerHTML} for @found };

is $found[0]->{innerHTML}, 'first', "We found the correct child";

@found = $mech->xpath( './/*[@class="child"]', node => $content );
is 0+@found, 1, "We find one child"
    or do { diag $_->{innerHTML} for @found };

is $found[0]->{innerHTML}, 'first', "We found the correct child";


# Check that refcounting works and releases the bridge once we release
# our $mech instance
my $destroyed;
my $old_DESTROY = \&MozRepl::RemoteObject::DESTROY;
{ no warnings 'redefine';
   *MozRepl::RemoteObject::DESTROY = sub {
       $destroyed++;
       goto $old_DESTROY;
   }
};

@found = ();
undef $content;
undef $mech;
$MozRepl::RemoteObject::WARN_ON_LEAKS = 1;
is $destroyed, 1, "Bridge was torn down";
