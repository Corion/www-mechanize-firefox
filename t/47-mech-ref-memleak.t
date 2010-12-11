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
    plan tests => 2;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

sub is_object($$$) {
    my ($l,$r,$name) = @_;
    my $is_id = $mech->repl->declare(<<'JS');
        function (l,r) {
            return l === r
        };
JS
    ok $is_id->($l,$r), $name
        or diag "Got $l->{tagName}, expected $r->{tagName}";
};

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

undef $mech;
$MozRepl::RemoteObject::WARN_ON_LEAKS = 1;
is $destroyed, 1, "Bridge was torn down";
