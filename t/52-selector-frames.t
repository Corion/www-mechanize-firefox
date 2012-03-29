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
    plan tests => 50;
};

isa_ok $mech, 'WWW::Mechanize::Firefox';

$mech->get_local('52-frameset.html');

my @content = $mech->xpath('//*[@id="content"]', frames => 1);
is scalar @content, 2, 'Querying of subframes returns results';
is $content[0]->{innerHTML}, '52-subframe.html', "We get the right frame";

@content = $mech->selector('#content', frames => 1);
is scalar @content, 2, 'Querying of subframes returns results via CSS selectors too';
is $content[0]->{innerHTML}, '52-subframe.html', "We get the right frame";

$mech->get_local('52-iframeset.html');

@content = $mech->xpath('//*[@id="content"]', frames => 1);
is scalar @content, 2, 'Querying of subframes returns results';
is $content[0]->{innerHTML}, '52-iframeset.html', "We get the right frame";
is $content[1]->{innerHTML}, '52-subframe.html', "We get the right frame";

@content = $mech->selector('#content', frames => 1);
is scalar @content, 2, 'Querying of subframes returns results via CSS selectors too';
is $content[0]->{innerHTML}, '52-iframeset.html', "We get the right frame";
is $content[1]->{innerHTML}, '52-subframe.html', "We get the right frame";

@content = $mech->selector('#content');
is scalar @content, 2, 'Querying of subframes returns results via CSS selectors too, even without frames=>1';
is $content[0]->{innerHTML}, '52-iframeset.html', "We get the right frame";
is $content[1]->{innerHTML}, '52-subframe.html', "We get the right frame";

@content = $mech->selector('#content', frames=>0);
is scalar @content, 1, 'Querying of subframes returns only the surrounding page with frames=>0';
is $content[0]->{innerHTML}, '52-iframeset.html', "We get the right frame";

my $bar;
my $v = eval { $bar = $mech->value('bar'); 1 };
ok $v, "We find input fields in subframes implicitly";
is $bar, 'foo', "We retrieve the right value";

diag "Testing deep framesets";
$mech->get_local('52-frameset-deep.html');

@content = $mech->xpath('//*[@id="content"]', frames => 0, one => 1);
is scalar @content, 1, 'Querying one element of subframes returns results';
is $content[0]->{innerHTML}, '52-frameset-deep.html', "We get the topmost frame if we only ask for one without diving into (deep) frames";

@content = $mech->xpath('//*[@id="content"]', one => 1);
is scalar @content, 1, 'Querying one element of subframes returns results';
is $content[0]->{innerHTML}, '52-frameset-deep.html', "We get the topmost frame if we only ask for one";

@content = $mech->xpath('//*[@id="content"]', frames => 1);
is scalar @content, 3, 'Querying of subframes returns results';
diag $content[0]->{innerHTML};
is $content[0]->{innerHTML}, '52-frameset-deep.html', "We get the right frame";
is $content[1]->{innerHTML}, '52-iframeset.html', "We get the right frame";
is $content[2]->{innerHTML}, '52-subframe.html', "We get the right frame";

@content = $mech->selector('#content', frames => 1);
is scalar @content, 3, 'Querying of subframes returns results via CSS selectors too';
is $content[0]->{innerHTML}, '52-frameset-deep.html', "We get the right frame";
is $content[1]->{innerHTML}, '52-iframeset.html', "We get the right frame";
is $content[2]->{innerHTML}, '52-subframe.html', "We get the right frame";

@content = $mech->selector('#content');
is scalar @content, 3, 'Querying of subframes returns results via CSS selectors too, even without frames=>1';
is $content[0]->{innerHTML}, '52-frameset-deep.html', "We get the right frame";
is $content[1]->{innerHTML}, '52-iframeset.html', "We get the right frame";
is $content[2]->{innerHTML}, '52-subframe.html', "We get the right frame";

@content = $mech->selector('#content', frames=>0);
is scalar @content, 1, 'Querying of subframes returns only the surrounding page with frames=>0';
is $content[0]->{innerHTML}, '52-frameset-deep.html', "We get the right frame";

undef $bar;
$v = eval { $bar = $mech->value('bar'); 1 };
ok $v, "We find input fields in subframes implicitly";
is $bar, 'foo', "We retrieve the right value";

diag "Testing recursive framesets";
$mech->get_local('52-frameset-recursive.html');

@content = $mech->xpath('//*[@id="content"]', frames => 0, one => 1);
is scalar @content, 1, 'Querying one element of subframes returns results';
is $content[0]->{innerHTML}, '52-frameset-recursive.html', "We get the topmost frame if we only ask for one without diving into (recursive) frames";

@content = $mech->xpath('//*[@id="content"]', one => 1);
is scalar @content, 1, 'Querying one element of subframes returns results';
is $content[0]->{innerHTML}, '52-frameset-recursive.html', "We get the topmost frame if we only ask for one";

@content = $mech->xpath('//*[@id="content"]', frames => 1);
ok scalar @content >= 4, 'Querying of subframes returns results';
diag $content[0]->{innerHTML};
is $content[0]->{innerHTML}, '52-frameset-recursive.html', "We get the right frame";
is $content[1]->{innerHTML}, '52-frameset-deep.html', "We get the right frame";
is $content[2]->{innerHTML}, '52-iframeset.html', "We get the right frame";
is $content[3]->{innerHTML}, '52-subframe.html', "We get the right frame";

@content = $mech->selector('#content', frames=>0);
is scalar @content, 1, 'Querying of subframes returns only the surrounding page with frames=>0';
is $content[0]->{innerHTML}, '52-frameset-recursive.html', "We get the right frame";

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

@content = ();
undef $mech;
$MozRepl::RemoteObject::WARN_ON_LEAKS = 1;
is $destroyed, 1, "Bridge was torn down";
