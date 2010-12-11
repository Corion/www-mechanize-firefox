#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;

my $mech = eval { WWW::Mechanize::Firefox->new( 
    autodie => 0,
    #log => [qw[debug]],
    #use_queue => 0,
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 2;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->get_local('52-frameset.html');

my @content = $mech->xpath('//*[@id="content"]', frames => 1);
@content = ();

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

$MozRepl::RemoteObject::WARN_ON_LEAKS = 1;
undef $mech;
is $destroyed, 1, "Bridge was torn down";
