#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::Firefox;
use URI::file;
use Cwd;
use File::Basename;

my %options = (
    autodie => 0,
    #log => [qw[debug]]
);

my $mech = eval {WWW::Mechanize::Firefox->new( %options )};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
    exit
} else {
    plan tests => 11;
};
undef $mech;

my @pages = qw(
    49-mech-get-file.html
    51-mech-sandbox.html
    53-mech-capture-js-noerror.html
);

my @mech = map {;
    WWW::Mechanize::Firefox->new( %options )
} @pages;

for my $mech (@mech) {
    isa_ok $mech, 'WWW::Mechanize::Firefox';
};

for my $page (0..$#pages) {
    $mech[ $page ]->get_local($pages[ $page ]);
};
for my $idx (0..$#mech) {
    my $mech = $mech[$idx];
    ok $mech->success;
    like $mech->uri, qr!/\Q$pages[ $idx ]\E$!i, "We navigated to the right file";
};

# Check that our destructors get called:
my %destroyed = (
    mech => 0,
    repl => 0,
);
{ no warnings 'redefine';
  my $old_repl = \&MozRepl::RemoteObject::DESTROY;
  *MozRepl::RemoteObject::DESTROY = sub {
      $destroyed{ repl }++;
      goto &$old_repl;
  };
  my $old_mech = \&WWW::Mechanize::Firefox::DESTROY;
  *WWW::Mechanize::Firefox::DESTROY = sub {
      $destroyed{ mech }++;
      goto &$old_mech;
  };
};

@mech = ();
is $destroyed{ repl }, 0+@pages, "All three repl instances got released";
is $destroyed{ mech }, 0+@pages, "All three mech instances got released";
